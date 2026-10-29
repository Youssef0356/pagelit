package com.the356company.pagelit

import android.app.Activity
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintDocumentInfo
import android.print.PrintManager
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.provider.Settings
import android.content.pm.PackageManager
import androidx.core.content.FileProvider
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.CompletableFuture
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "pagelit/deeplink"
    private val devicePdfsChannelName = "pagelit/device_pdfs"

    /** Supported document extensions (PDF + MS Office). */
    private val supportedExtensions = listOf(".pdf", ".docx", ".xlsx", ".pptx", ".doc", ".xls", ".ppt")

    /** Activity result code for the system "choose a folder" picker. */
    private val pickFolderRequestCode = 4107

    /** Set while the folder picker is open; receives the chosen tree URI. */
    private var pendingFolderResult: MethodChannel.Result? = null

    /** Resolved documents live here, one per shared URI, and survive app restarts. */
    private val sharedPdfsDir by lazy { File(cacheDir, "shared_pdfs") }

    /** Content URIs are copied on this thread: never on the UI thread. */
    private val ioExecutor = Executors.newSingleThreadExecutor()

    /**
     * Result of the most recent "open with" intent. Resolution starts the
     * moment the intent arrives — i.e. *while Flutter is still booting* — and
     * Dart consumes it exactly once.
     */
    private var pendingPdf: CompletableFuture<String?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialPdfPath" -> consumePdfIntent(result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, devicePdfsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasAllFilesAccess" -> result.success(hasAllFilesAccess())
                    "requestAllFilesAccess" -> result.success(requestAllFilesAccess())
                    "listPdfs" -> {
                        val folders = call.argument<List<String>>("folders") ?: emptyList()
                        ioExecutor.execute {
                            val pdfs = runCatching { listPdfs(folders) }.getOrDefault(emptyList())
                            runOnUiThread { result.success(pdfs) }
                        }
                    }
                    "pickFolder" -> pickFolder(result)
                    "releaseFolder" -> {
                        releaseFolder(call.argument<String>("uri"))
                        result.success(true)
                    }
                    "resolvePdf" -> {
                        val uri = call.argument<String>("uri")
                        ioExecutor.execute {
                            val path = if (uri == null) null else copySharedPdf(Uri.parse(uri))
                            runOnUiThread { result.success(path) }
                        }
                    }
                    "getCacheSize" -> {
                        ioExecutor.execute {
                            val size = if (sharedPdfsDir.exists()) {
                                sharedPdfsDir.walkTopDown().filter { it.isFile }.sumOf { it.length() }
                            } else {
                                0L
                            }
                            runOnUiThread { result.success(size) }
                        }
                    }
                    "clearCache" -> {
                        ioExecutor.execute {
                            val success = runCatching {
                                if (sharedPdfsDir.exists()) {
                                    sharedPdfsDir.deleteRecursively()
                                }
                                sharedPdfsDir.mkdirs()
                                true
                            }.getOrDefault(false)
                            runOnUiThread { result.success(success) }
                        }
                    }
                    "printFile" -> {
                        val path = call.argument<String>("path")
                        printDocument(path, result)
                    }
                    "openGemini" -> {
                        val filePath = call.argument<String>("filePath")
                        val prompt = call.argument<String>("prompt") ?: ""
                        result.success(openGemini(filePath, prompt))
                    }
                    "isGeminiInstalled" -> {
                        result.success(isGeminiInstalled())
                    }
                    else -> result.notImplemented()
                }
            }
        // Warm the intent before the first frame is even drawn.
        startPdfIntent(intent)
    }

    // ------------------------------------------------------------ device documents

    /** True when the user granted "All files access" (Android 11+). */
    private fun hasAllFilesAccess(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && Environment.isExternalStorageManager()

    /** Opens the system screen where "All files access" can be granted. */
    private fun requestAllFilesAccess(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        return try {
            startActivity(
                Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                    .setData(Uri.parse("package:$packageName")),
            )
            true
        } catch (_: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    /**
     * Every document the app can see, newest first.
     */
    private fun listPdfs(folderUris: List<String>): List<Map<String, Any?>> {
        val byKey = LinkedHashMap<String, Map<String, Any?>>()

        fun addAll(items: List<Map<String, Any?>>) {
            for (item in items) {
                val key = (item["uri"] as? String) ?: (item["path"] as? String) ?: continue
                val existing = byKey[key]
                if (existing == null || (existing["path"] == null && item["path"] != null)) {
                    byKey[key] = item
                }
            }
        }

        if (hasAllFilesAccess()) {
            val indexed = runCatching { queryMediaStorePdfs() }.getOrDefault(emptyList())
            addAll(if (indexed.isEmpty()) runCatching { walkExternalStorage() }.getOrDefault(emptyList()) else indexed)
        }
        for (folder in folderUris) {
            addAll(runCatching { scanFolder(Uri.parse(folder)) }.getOrDefault(emptyList()))
        }
        return byKey.values.sortedByDescending { (it["modified"] as? Long) ?: 0L }
    }

    /** Queries the MediaStore index for documents, newest first. */
    @Suppress("DEPRECATION")
    private fun queryMediaStorePdfs(): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Files.getContentUri("external")
        }
        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.SIZE,
            MediaStore.Files.FileColumns.DATE_MODIFIED,
            MediaStore.Files.FileColumns.MIME_TYPE,
            MediaStore.MediaColumns.DATA,
        )
        val selection = "(${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ? " +
                "OR ${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ? " +
                "OR ${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ? " +
                "OR ${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ? " +
                "OR ${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ? " +
                "OR ${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ? " +
                "OR ${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ? " +
                "OR ${MediaStore.Files.FileColumns.MIME_TYPE} LIKE 'application/%pdf%' " +
                "OR ${MediaStore.Files.FileColumns.MIME_TYPE} LIKE 'application/%word%' " +
                "OR ${MediaStore.Files.FileColumns.MIME_TYPE} LIKE 'application/%sheet%' " +
                "OR ${MediaStore.Files.FileColumns.MIME_TYPE} LIKE 'application/%presentation%')"
        val args = arrayOf("%.pdf", "%.docx", "%.xlsx", "%.pptx", "%.doc", "%.xls", "%.ppt")
        val order = "${MediaStore.Files.FileColumns.DATE_MODIFIED} DESC"
        contentResolver.query(collection, projection, selection, args, order)?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
            val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
            val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
            val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED)
            val dataCol = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
            while (cursor.moveToNext()) {
                val name = cursor.getString(nameCol) ?: continue
                val id = cursor.getLong(idCol)
                val path = if (dataCol >= 0 && !cursor.isNull(dataCol)) cursor.getString(dataCol) else null
                out.add(
                    mapOf(
                        "name" to name,
                        "uri" to ContentUris.withAppendedId(collection, id).toString(),
                        "path" to path,
                        "size" to if (cursor.isNull(sizeCol)) 0L else cursor.getLong(sizeCol),
                        "modified" to if (cursor.isNull(dateCol)) 0L else cursor.getLong(dateCol) * 1000L,
                    ),
                )
            }
        }
        return out
    }

    /**
     * Recursively walks shared storage looking for documents.
     */
    private fun walkExternalStorage(): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        val root = Environment.getExternalStorageDirectory() ?: return out
        val skip = setOf("Android", "LOST.DIR", ".thumbnails", ".trash")
        fun walk(dir: File, depth: Int) {
            if (depth > 8) return
            val children = dir.listFiles() ?: return
            for (child in children) {
                if (child.isDirectory) {
                    if (child.name !in skip) walk(child, depth + 1)
                } else if (supportedExtensions.any { child.name.endsWith(it, ignoreCase = true) }) {
                    out.add(
                        mapOf(
                            "name" to child.name,
                            "uri" to null,
                            "path" to child.absolutePath,
                            "size" to child.length(),
                            "modified" to child.lastModified(),
                        ),
                    )
                }
            }
        }
        runCatching { walk(root, 0) }
        return out
    }

    /** Scans a user-chosen folder (and its sub-folders) for documents. */
    private fun scanFolder(treeUri: Uri): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        val root = DocumentFile.fromTreeUri(this, treeUri) ?: return out

        fun walk(dir: DocumentFile, depth: Int) {
            if (depth > 12) return
            val children = runCatching { dir.listFiles() }.getOrDefault(emptyArray())
            for (child in children) {
                if (child.isDirectory) {
                    walk(child, depth + 1)
                    continue
                }
                val name = child.name ?: continue
                val type = child.type.orEmpty()
                val isDoc = supportedExtensions.any { name.endsWith(it, ignoreCase = true) } ||
                        type.contains("pdf") || type.contains("word") || type.contains("sheet") ||
                        type.contains("presentation") || type.contains("officedocument")
                if (!isDoc) continue
                out.add(
                    mapOf(
                        "name" to name,
                        "uri" to child.uri.toString(),
                        "path" to null,
                        "size" to child.length(),
                        "modified" to child.lastModified(),
                    ),
                )
            }
        }

        walk(root, 0)
        return out
    }

    /** Lets the user grant read access to a folder through the SAF picker. */
    private fun pickFolder(result: MethodChannel.Result) {
        if (pendingFolderResult != null) {
            result.error("busy", "A folder picker is already open.", null)
            return
        }
        pendingFolderResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        try {
            startActivityForResult(intent, pickFolderRequestCode)
        } catch (e: Exception) {
            pendingFolderResult = null
            result.error("unavailable", e.message, null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickFolderRequestCode) return
        val result = pendingFolderResult ?: return
        pendingFolderResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        runCatching {
            contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        result.success(uri.toString())
    }

    /** Drops the persisted permission of a folder the user removed. */
    private fun releaseFolder(uri: String?) {
        val parsed = uri?.let { runCatching { Uri.parse(it) }.getOrNull() } ?: return
        runCatching {
            contentResolver.releasePersistableUriPermission(parsed, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
    }

    // --------------------------------------------------------------- print

    private fun printDocument(path: String?, result: MethodChannel.Result) {
        if (path == null) {
            result.error("invalid_path", "Path is null", null)
            return
        }
        val file = File(path)
        if (!file.exists()) {
            result.error("not_found", "File does not exist: $path", null)
            return
        }
        val printManager = getSystemService(Context.PRINT_SERVICE) as? PrintManager
        if (printManager == null) {
            result.error("unavailable", "PrintManager unavailable on this device", null)
            return
        }
        val adapter = object : PrintDocumentAdapter() {
            override fun onLayout(
                oldAttributes: PrintAttributes?,
                newAttributes: PrintAttributes?,
                cancellationSignal: CancellationSignal?,
                callback: LayoutResultCallback?,
                extras: Bundle?
            ) {
                if (cancellationSignal?.isCanceled == true) {
                    callback?.onLayoutCancelled()
                    return
                }
                val info = PrintDocumentInfo.Builder(file.name)
                    .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                    .build()
                callback?.onLayoutFinished(info, true)
            }

            override fun onWrite(
                pages: Array<out PageRange>?,
                destination: ParcelFileDescriptor?,
                cancellationSignal: CancellationSignal?,
                callback: WriteResultCallback?
            ) {
                if (cancellationSignal?.isCanceled == true) {
                    callback?.onWriteCancelled()
                    return
                }
                try {
                    file.inputStream().use { input ->
                        FileOutputStream(destination?.fileDescriptor).use { output ->
                            input.copyTo(output)
                        }
                    }
                    callback?.onWriteFinished(arrayOf(PageRange.ALL_PAGES))
                } catch (e: Exception) {
                    callback?.onWriteFailed(e.message)
                }
            }
        }
        printManager.print(file.name, adapter, PrintAttributes.Builder().build())
        result.success(true)
    }

    // --------------------------------------------------------------- gemini

    /** Checks whether the official Google Gemini app is installed. */
    private fun isGeminiInstalled(): Boolean {
        return try {
            packageManager.getPackageInfo("com.google.android.apps.bard", 0)
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Opens Google Gemini directly with the given image and prompt.
     * Returns true if successfully launched, false if Gemini app is not installed.
     */
    private fun openGemini(filePath: String?, prompt: String): Boolean {
        if (!isGeminiInstalled()) {
            return false
        }
        return try {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                if (filePath != null) {
                    val file = File(filePath)
                    if (file.exists()) {
                        val uri = FileProvider.getUriForFile(
                            this@MainActivity,
                            "${applicationContext.packageName}.fileprovider",
                            file
                        )
                        putExtra(Intent.EXTRA_STREAM, uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                }
                if (prompt.isNotEmpty()) {
                    putExtra(Intent.EXTRA_TEXT, prompt)
                }
                setPackage("com.google.android.apps.bard")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    // --------------------------------------------------------------- deeplinks

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        startPdfIntent(intent)
    }

    /** Kicks off resolution of [intent]'s document, immediately. */
    private fun startPdfIntent(intent: Intent?) {
        val uri = intent?.data ?: return
        val future = CompletableFuture<String?>()
        pendingPdf = future
        when (uri.scheme) {
            "file" -> future.complete(uri.path)
            "content" -> ioExecutor.execute { future.complete(copySharedPdf(uri)) }
            else -> future.complete(null)
        }
    }

    /** Returns the pending result to Dart and clears it (consume once). */
    private fun consumePdfIntent(result: MethodChannel.Result) {
        val future = pendingPdf ?: run {
            result.success(null)
            return
        }
        pendingPdf = null
        future.whenComplete { path, _ -> runOnUiThread { result.success(path) } }
    }

    /**
     * Copies a shared content:// document into the cache so Dart can read it.
     */
    private fun copySharedPdf(uri: Uri): String? {
        return try {
            val name = queryDisplayName(uri)
            val size = querySize(uri)
            val outFile = File(
                sharedPdfsDir,
                "${Integer.toHexString(uri.toString().hashCode())}_$name",
            )
            val alreadyCopied = outFile.exists() && (size == null || outFile.length() == size)
            if (!alreadyCopied) {
                sharedPdfsDir.mkdirs()
                val input = contentResolver.openInputStream(uri) ?: return null
                input.use { ins ->
                    outFile.outputStream().use { out -> ins.copyTo(out, 128 * 1024) }
                }
            }
            outFile.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    /** The original file name, made safe to use as a single path segment. */
    private fun queryDisplayName(uri: Uri): String {
        val display = runCatching {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index >= 0 && cursor.moveToFirst()) cursor.getString(index) else null
                }
        }.getOrNull() ?: uri.lastPathSegment
        val decoded = runCatching {
            if (display != null && display.contains("%")) {
                java.net.URLDecoder.decode(display, "UTF-8")
            } else {
                display
            }
        }.getOrNull() ?: display
        val safe = (decoded ?: display)
            ?.replace('/', '_')
            ?.replace('\\', '_')
            ?.trim()
            .orEmpty()
        return if (safe.isEmpty() || safe == "." || safe == "..") "shared_doc.pdf" else safe
    }

    /** Size of the shared file, used to validate a cached copy. */
    private fun querySize(uri: Uri): Long? = runCatching {
        contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getLong(0) else null
        }
    }.getOrNull()
}

package com.the356company.pagelit

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.CompletableFuture
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "pagelit/deeplink"

    /** Resolved PDFs live here, one per shared URI, and survive app restarts. */
    private val sharedPdfsDir by lazy { File(cacheDir, "shared_pdfs") }

    /** Content URIs are copied on this thread: never on the UI thread. */
    private val ioExecutor = Executors.newSingleThreadExecutor()

    /**
     * Result of the most recent "open with" intent. Resolution starts the
     * moment the intent arrives — i.e. *while Flutter is still booting* — and
     * Dart consumes it exactly once, so:
     *  - the file copy no longer sits on the critical path after the first
     *    frame, and
     *  - a document is never reopened on a later app resume.
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
        // Warm the intent before the first frame is even drawn.
        startPdfIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // singleTop: a second "open with" tap reuses this activity, so keep
        // the latest intent and start resolving it right away.
        setIntent(intent)
        startPdfIntent(intent)
    }

    /** Kicks off resolution of [intent]'s PDF, immediately. */
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
     * Copies a shared content:// PDF into the cache so Dart can read it
     * (Flutter cannot read content URIs directly, and the sharing app may
     * revoke access at any moment).
     *
     * A copy made earlier for the same URI and size is reused, so reopening
     * a document shared from e.g. WhatsApp is instant instead of re-copying.
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
                // Wide buffer: shared PDFs are often tens of megabytes.
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
        }.getOrNull()
        val safe = display
            ?.replace('/', '_')
            ?.replace('\\', '_')
            ?.trim()
            .orEmpty()
        return if (safe.isEmpty() || safe == "." || safe == "..") "shared.pdf" else safe
    }

    /** Size of the shared file, used to validate a cached copy. */
    private fun querySize(uri: Uri): Long? = runCatching {
        contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getLong(0) else null
        }
    }.getOrNull()
}

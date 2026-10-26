// Generated localizations
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Extension to easily access localizations via `context.l10n`.
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Abstract localization contract containing all strings in Pagelit.
abstract class AppLocalizations {
  const AppLocalizations();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const _AppLocalizationsEn();
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('fr'),
    Locale('ar'),
  ];

  // Common
  String get appTitle;
  String get cancel;
  String get close;
  String get save;
  String get clear;
  String get delete;
  String get remove;
  String get retry;
  String get refresh;
  String get search;
  String get settings;
  String get share;
  String get details;
  String get open;
  String get unlock;
  String get go;
  String get more;
  String get undo;

  // Home Screen
  String get openPdf;
  String get searchDocuments;
  String get searchFilesHint;
  String get sortBy;
  String get sortDate;
  String get sortName;
  String get sortSize;
  String get onThisDevice;
  String get recentFiles;
  String get scannedFolders;
  String get addFolder;
  String get removeFolder;
  String get welcomeTitle;
  String get welcomeSubtitle;
  String get openFirstPdf;
  String get findPdfsOnDevice;
  String get showPdfsOnDevice;
  String get deviceAccessDescription;
  String get allowAccess;
  String get chooseFolder;
  String get lookingForDocuments;
  String get noMatchingFiles;
  String get noDocumentsYet;
  String get fileOptions;
  String get removeFromRecents;
  String get fileNotFound;
  String get couldNotOpenDocument;
  String get chooseFolderPrompt;
  String get noCustomFolders;
  String scannedFoldersCount(int count);
  String get noCustomFoldersSelected;

  // Relative Date & Metadata
  String get justNow;
  String minutesAgo(int minutes);
  String hoursAgo(int hours);
  String daysAgo(int days);
  String pageXOfY(int page, int total, int percent, String dateOrSize);
  String formatBytes(int bytes);

  // File Details Dialog
  String get fileDetails;
  String get fileName;
  String get fileType;
  String get fileSize;
  String get fileModified;
  String get fileLocation;
  String get pdfDocumentType;
  String get wordDocumentType;
  String get excelSpreadsheetType;
  String get powerPointPresentationType;

  // Settings Screen
  String get appearance;
  String get themeSystem;
  String get themeLight;
  String get themeDark;

  String get language;
  String get languageSystem;
  String get languageEn;
  String get languageFr;
  String get languageAr;

  String get reading;
  String get keepScreenOn;
  String get whileDocumentIsOpen;
  String get pageLayout;
  String get layoutContinuous;
  String get layoutSingle;
  String get scrollDirection;
  String get scrollVertical;
  String get scrollHorizontal;
  String get comfortMode;
  String get comfortNormal;
  String get comfortSepia;
  String get comfortDim;
  String get comfortNight;

  String get annotations;
  String get storageAndFolders;
  String get clearSharedCache;
  String temporaryCopies(String size);
  String get clearCacheTitle;
  String get clearCacheContent;
  String get cacheClearedSnackbar;
  String get clearRecentsTitle;
  String get clearRecentsSubtitle;
  String get clearRecentsConfirmTitle;
  String get clearRecentsConfirmContent;
  String get recentsClearedSnackbar;

  // Premium Section
  String get premium;
  String get removeAds;
  String get premiumActiveSubtitle;
  String get oneTimePurchase;
  String oneTimePurchaseWithPrice(String price);
  String get restorePurchases;
  String get simulatePremium;
  String get simulatePremiumSubtitle;
  String get playBillingUnavailableTitle;
  String get playBillingUnavailableContent;
  String get activatePremium;
  String get premiumActivatedSnackbar;
  String get noPreviousPurchase;
  String get billingConnectError;
  String get billingPurchaseError;

  // About Section
  String get about;
  String get version;
  String get privacyPolicy;

  // Reader Screen
  String get passwordProtected;
  String get passwordPrompt;
  String get passwordHint;
  String couldNotOpenPdf(String error);
  String get tableOfContents;
  String get noTableOfContents;
  String get goToPage;
  String get pageNumberHint;
  String get ofWord;
  String pageMustBeBetween(int count);
  String get searchInDocument;
  String get closeSearch;
  String get previousMatch;
  String get nextMatch;
  String get noResults;
  String get fullScreen;
  String get exitFullScreen;
  String get askGemini;
  String get askGeminiAboutPage;
  String get comments;
  String get sharePdf;
  String get rotate90;
  String get printDocument;
  String get saveAnnotatedCopy;
  String get saveCurrentViewToGallery;
  String get toolReadPan;
  String get toolHighlight;
  String get toolUnderline;
  String get toolStrikethrough;
  String get toolSquiggly;
  String get toolComment;
  String get annotationColor;
  String get deleteAnnotation;
  String get deleteComment;
  String get addComment;
  String get commentHint;
  String get noCommentsYet;
  String get noCommentsLeft;
  String viewOfPageSaved(int page);
  String savedToPath(String path);
  String get openingDocument;
  String get printingNotSupported;

  // Office Viewers
  String get searchCellContents;
  String get emptyWorkbook;
  String get sheetContainsNoData;
  String get copyValue;
  String get copiedCellText;
  String get saveSheetViewToGallery;
  String sheetViewSaved(String sheetName);
  String get emptyCell;
  String get dismiss;

  String get searchWordHint;
  String get smallerText;
  String get largerText;
  String get saveWordViewToGallery;
  String get documentViewSaved;
  String get wordDocumentEmpty;

  String allSlidesCount(int count);
  String slideXOfY(int index, int total);
  String slideNumber(int number);
  String get slideTitleOnly;
  String get saveSlideToGallery;
  String slideSaved(int number);
  String get saveImageToGallery;
  String get imageSavedToGallery;
  String get aspectRatioMode;
  String get expandedBigContainer;
  String get searchPresentationHint;
  String get presentationHasNoSlides;

  // Gallery & Share services
  String get viewerNotReady;
  String get couldNotGenerateSnapshot;
  String get galleryPermissionDenied;
  String get savedToGallerySuccess;
  String askGeminiTitle(String title);
  String couldNotShare(String error);
  String couldNotSave(String error);
  String couldNotSaveToGallery(String error);
  String couldNotShareToGemini(String error);

  // Splash & Onboarding
  String get splashTagline;
  String get welcomeToPagelit;
  String get chooseThemeTitle;
  String get chooseThemeSubtitle;
  String get themeLightTitle;
  String get themeLightSubtitle;
  String get themeDarkTitle;
  String get themeDarkSubtitle;
  String get chooseLanguageTitle;
  String get chooseLanguageSubtitle;
  String get continueButton;
  String get getStarted;
  String get stepTheme;
  String get stepLanguage;
  String get previous;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'fr', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(_lookup(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;

  AppLocalizations _lookup(Locale locale) {
    switch (locale.languageCode) {
      case 'fr':
        return const _AppLocalizationsFr();
      case 'ar':
        return const _AppLocalizationsAr();
      case 'en':
      default:
        return const _AppLocalizationsEn();
    }
  }
}

// -----------------------------------------------------------------------------
// English (Default)
// -----------------------------------------------------------------------------
class _AppLocalizationsEn extends AppLocalizations {
  const _AppLocalizationsEn();

  @override
  String get appTitle => "Pagelit";
  @override
  String get cancel => "Cancel";
  @override
  String get close => "Close";
  @override
  String get save => "Save";
  @override
  String get clear => "Clear";
  @override
  String get delete => "Delete";
  @override
  String get remove => "Remove";
  @override
  String get retry => "Retry";
  @override
  String get refresh => "Refresh";
  @override
  String get search => "Search";
  @override
  String get settings => "Settings";
  @override
  String get share => "Share";
  @override
  String get details => "Details";
  @override
  String get open => "Open";
  @override
  String get unlock => "Unlock";
  @override
  String get go => "Go";
  @override
  String get more => "More options";
  @override
  String get undo => "Undo";

  @override
  String get openPdf => "Open PDF";
  @override
  String get searchDocuments => "Search documents";
  @override
  String get searchFilesHint => "Search files by name...";
  @override
  String get sortBy => "Sort by";
  @override
  String get sortDate => "Date (Newest first)";
  @override
  String get sortName => "Name (A–Z)";
  @override
  String get sortSize => "File Size (Largest first)";
  @override
  String get onThisDevice => "ON THIS DEVICE";
  @override
  String get recentFiles => "RECENT FILES";
  @override
  String get scannedFolders => "Scanned folders";
  @override
  String get addFolder => "Add folder";
  @override
  String get removeFolder => "Remove folder";
  @override
  String get welcomeTitle => "Welcome to Pagelit";
  @override
  String get welcomeSubtitle =>
      "Open a PDF, Word, Excel or PowerPoint file to start reading.\nHighlight, annotate, search, share, or save pages to gallery.";
  @override
  String get openFirstPdf => "Open your first PDF";
  @override
  String get findPdfsOnDevice => "Find PDFs on this device";
  @override
  String get showPdfsOnDevice => "Show PDFs on this device";
  @override
  String get deviceAccessDescription =>
      "Pagelit can list every PDF and Office document stored on your phone, newest first. Allow full storage access, or pick folders to scan.";
  @override
  String get allowAccess => "Allow access";
  @override
  String get chooseFolder => "Choose folder";
  @override
  String get lookingForDocuments => "Looking for documents…";
  @override
  String get noMatchingFiles => "No matching files found.";
  @override
  String get noDocumentsYet =>
      "No documents found yet. Add another folder to scan.";
  @override
  String get fileOptions => "File options";
  @override
  String get removeFromRecents => "Remove from recents";
  @override
  String get fileNotFound => "FILE NOT FOUND";
  @override
  String get couldNotOpenDocument => "Could not open that document.";
  @override
  String get chooseFolderPrompt =>
      "Choose a folder so Pagelit can find your PDFs.";
  @override
  String get noCustomFolders =>
      "No custom folders added yet.\nTap the + button to select a folder to scan.";
  @override
  String scannedFoldersCount(int count) =>
      "$count custom folder${count == 1 ? '' : 's'} scanned";
  @override
  String get noCustomFoldersSelected => "No custom folders selected";

  @override
  String get justNow => "Just now";
  @override
  String minutesAgo(int minutes) => "$minutes min ago";
  @override
  String hoursAgo(int hours) => "$hours h ago";
  @override
  String daysAgo(int days) => "$days d ago";
  @override
  String pageXOfY(int page, int total, int percent, String dateOrSize) =>
      "PAGE $page OF $total · $percent% · $dateOrSize";

  @override
  String formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const units = ["B", "KB", "MB", "GB"];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final digits = unit == 0 || value >= 100 ? 0 : 1;
    return "${value.toStringAsFixed(digits)} ${units[unit]}";
  }

  @override
  String get fileDetails => "File Details";
  @override
  String get fileName => "Name";
  @override
  String get fileType => "Type";
  @override
  String get fileSize => "Size";
  @override
  String get fileModified => "Modified";
  @override
  String get fileLocation => "Location";
  @override
  String get pdfDocumentType => "PDF Document";
  @override
  String get wordDocumentType => "Microsoft Word Document";
  @override
  String get excelSpreadsheetType => "Microsoft Excel Spreadsheet";
  @override
  String get powerPointPresentationType => "Microsoft PowerPoint Presentation";

  @override
  String get appearance => "APPEARANCE";
  @override
  String get themeSystem => "System";
  @override
  String get themeLight => "Light";
  @override
  String get themeDark => "Dark";

  @override
  String get language => "LANGUAGE";
  @override
  String get languageSystem => "System Default";
  @override
  String get languageEn => "English";
  @override
  String get languageFr => "Français";
  @override
  String get languageAr => "العربية";

  @override
  String get reading => "READING";
  @override
  String get keepScreenOn => "Keep screen on";
  @override
  String get whileDocumentIsOpen => "While a document is open";
  @override
  String get pageLayout => "Page layout";
  @override
  String get layoutContinuous => "Continuous";
  @override
  String get layoutSingle => "One page";
  @override
  String get scrollDirection => "Scroll direction";
  @override
  String get scrollVertical => "Vertical";
  @override
  String get scrollHorizontal => "Horizontal";
  @override
  String get comfortMode => "Comfort & Night mode";
  @override
  String get comfortNormal => "Normal";
  @override
  String get comfortSepia => "Sepia";
  @override
  String get comfortDim => "Dim";
  @override
  String get comfortNight => "Night";

  @override
  String get annotations => "ANNOTATIONS";
  @override
  String get storageAndFolders => "STORAGE & FOLDERS";
  @override
  String get clearSharedCache => "Clear shared document cache";
  @override
  String temporaryCopies(String size) => "Temporary copies: $size";
  @override
  String get clearCacheTitle => "Clear cached files?";
  @override
  String get clearCacheContent =>
      "This will remove temporary copies of documents opened from other apps (WhatsApp, Downloads, Drive). Your original files on device are not deleted.";
  @override
  String get cacheClearedSnackbar => "Document cache cleared";
  @override
  String get clearRecentsTitle => "Clear recents and progress";
  @override
  String get clearRecentsSubtitle => "Removes the list and reading positions";
  @override
  String get clearRecentsConfirmTitle => "Clear recents?";
  @override
  String get clearRecentsConfirmContent =>
      "This removes your recent files list, cached documents, and every saved reading position. Your original documents are not deleted.";
  @override
  String get recentsClearedSnackbar => "Recents, cache, and progress cleared";

  @override
  String get premium => "PREMIUM";
  @override
  String get removeAds => "Remove ads";
  @override
  String get premiumActiveSubtitle => "Thank you! Ads are off everywhere.";
  @override
  String get oneTimePurchase => "One-time purchase";
  @override
  String oneTimePurchaseWithPrice(String price) => "One-time purchase · $price";
  @override
  String get restorePurchases => "Restore purchases";
  @override
  String get simulatePremium => "Simulate premium (test mode)";
  @override
  String get simulatePremiumSubtitle =>
      "Enable ad-free mode for testing (persists on this device)";
  @override
  String get playBillingUnavailableTitle => "Play Billing Unavailable";
  @override
  String get playBillingUnavailableContent =>
      "Google Play Billing could not find the in-app product \"remove_ads\".\n\nThis is normal during local development or before the product is published on Google Play.\n\nWould you like to activate Premium in test mode now?";
  @override
  String get activatePremium => "Activate Premium";
  @override
  String get premiumActivatedSnackbar => "Premium activated! Ads are removed.";
  @override
  String get noPreviousPurchase => "No previous purchase found.";
  @override
  String get billingConnectError =>
      "Unable to connect to Google Play. Please check your internet connection and Google Play Services.";
  @override
  String get billingPurchaseError =>
      "Could not start the purchase. Please try again.";

  @override
  String get about => "ABOUT";
  @override
  String get version => "Version";
  @override
  String get privacyPolicy => "Privacy policy";

  @override
  String get passwordProtected => "Password Protected";
  @override
  String get passwordPrompt =>
      "This document is encrypted. Enter password to open:";
  @override
  String get passwordHint => "Password";
  @override
  String couldNotOpenPdf(String error) => "Could not open PDF: $error";
  @override
  String get tableOfContents => "Table of contents";
  @override
  String get noTableOfContents => "This document has no table of contents.";
  @override
  String get goToPage => "Go to page";
  @override
  String get pageNumberHint => "Page number";
  @override
  String get ofWord => "of";
  @override
  String pageMustBeBetween(int count) => "Page must be between 1 and $count";
  @override
  String get searchInDocument => "Search in document";
  @override
  String get closeSearch => "Close search";
  @override
  String get previousMatch => "Previous match";
  @override
  String get nextMatch => "Next match";
  @override
  String get noResults => "No results";
  @override
  String get fullScreen => "Full screen";
  @override
  String get exitFullScreen => "Exit full screen";
  @override
  String get askGemini => "Ask Gemini";
  @override
  String get askGeminiAboutPage => "Ask Gemini about this page";
  @override
  String get comments => "Comments & Notes";
  @override
  String get sharePdf => "Share PDF";
  @override
  String get rotate90 => "Rotate (90°)";
  @override
  String get printDocument => "Print document";
  @override
  String get saveAnnotatedCopy => "Save annotated copy";
  @override
  String get saveCurrentViewToGallery => "Save current view to gallery";
  @override
  String get toolReadPan => "Read / pan";
  @override
  String get toolHighlight => "Highlight";
  @override
  String get toolUnderline => "Underline";
  @override
  String get toolStrikethrough => "Strikethrough";
  @override
  String get toolSquiggly => "Squiggly";
  @override
  String get toolComment => "Comment";
  @override
  String get annotationColor => "Annotation colour";
  @override
  String get deleteAnnotation => "Delete annotation";
  @override
  String get deleteComment => "Delete comment";
  @override
  String get addComment => "Add comment";
  @override
  String get commentHint => "Write a note about this spot…";
  @override
  String get noCommentsYet =>
      "No comments yet. Tap with the comment tool to add one.";
  @override
  String get noCommentsLeft => "No comments left";
  @override
  String viewOfPageSaved(int page) => "View of page $page saved to gallery";
  @override
  String savedToPath(String path) => "Saved to $path";
  @override
  String get openingDocument => "Opening document…";
  @override
  String get printingNotSupported =>
      "Printing is not supported on this device.";

  @override
  String get searchCellContents => "Search cell contents...";
  @override
  String get emptyWorkbook => "Empty workbook";
  @override
  String get sheetContainsNoData => "This sheet contains no data.";
  @override
  String get copyValue => "Copy value";
  @override
  String get copiedCellText => "Copied cell text to clipboard";
  @override
  String get saveSheetViewToGallery => "Save sheet view to gallery";
  @override
  String sheetViewSaved(String sheetName) =>
      "Sheet \"$sheetName\" view saved to gallery";
  @override
  String get emptyCell => "(Empty)";
  @override
  String get dismiss => "Dismiss";

  @override
  String get searchWordHint => "Search in document...";
  @override
  String get smallerText => "Smaller text";
  @override
  String get largerText => "Larger text";
  @override
  String get saveWordViewToGallery => "Save view to gallery";
  @override
  String get documentViewSaved => "Document view saved to gallery";
  @override
  String get wordDocumentEmpty => "This document is empty.";

  @override
  String allSlidesCount(int count) => "All Slides ($count)";
  @override
  String slideXOfY(int index, int total) => "Slide $index of $total";
  @override
  String slideNumber(int number) => "Slide $number";
  @override
  String get slideTitleOnly => "(Slide title only)";
  @override
  String get saveSlideToGallery => "Save slide to gallery";
  @override
  String slideSaved(int number) => "Slide $number saved to gallery";
  @override
  String get saveImageToGallery => "Save image to gallery";
  @override
  String get imageSavedToGallery => "Image saved to gallery";
  @override
  String get aspectRatioMode => "Aspect ratio mode (16:9)";
  @override
  String get expandedBigContainer => "Expanded big container";
  @override
  String get searchPresentationHint =>
      "Search slide text (diacritic-friendly)...";
  @override
  String get presentationHasNoSlides => "This presentation has no slides.";

  @override
  String get viewerNotReady => "Viewer is not ready to capture";
  @override
  String get couldNotGenerateSnapshot => "Could not generate image snapshot";
  @override
  String get galleryPermissionDenied => "Gallery permission denied";
  @override
  String get savedToGallerySuccess => "Saved to gallery successfully";
  @override
  String askGeminiTitle(String title) => "Ask Gemini: $title";
  @override
  String couldNotShare(String error) => "Could not share: $error";
  @override
  String couldNotSave(String error) => "Could not save: $error";
  @override
  String couldNotSaveToGallery(String error) =>
      "Could not save to gallery: $error";
  @override
  String couldNotShareToGemini(String error) =>
      "Could not share to Gemini: $error";

  // Splash & Onboarding
  @override
  String get splashTagline => "Fast, clean & private document reader";
  @override
  String get welcomeToPagelit => "Welcome to Pagelit";
  @override
  String get chooseThemeTitle => "Choose appearance";
  @override
  String get chooseThemeSubtitle =>
      "Select your preferred style. You can adjust this anytime in Settings.";
  @override
  String get themeLightTitle => "Light Mode";
  @override
  String get themeLightSubtitle => "Clean & crisp for daylight reading";
  @override
  String get themeDarkTitle => "Dark Mode";
  @override
  String get themeDarkSubtitle => "Gentle on your eyes in low light";
  @override
  String get chooseLanguageTitle => "Choose language";
  @override
  String get chooseLanguageSubtitle =>
      "Select your preferred display language for the interface.";
  @override
  String get continueButton => "Continue";
  @override
  String get getStarted => "Get Started";
  @override
  String get stepTheme => "Theme";
  @override
  String get stepLanguage => "Language";
  @override
  String get previous => "Back";
}

// -----------------------------------------------------------------------------
// French (Français)
// -----------------------------------------------------------------------------
class _AppLocalizationsFr extends AppLocalizations {
  const _AppLocalizationsFr();

  @override
  String get appTitle => "Pagelit";
  @override
  String get cancel => "Annuler";
  @override
  String get close => "Fermer";
  @override
  String get save => "Enregistrer";
  @override
  String get clear => "Effacer";
  @override
  String get delete => "Supprimer";
  @override
  String get remove => "Supprimer";
  @override
  String get retry => "Réessayer";
  @override
  String get refresh => "Actualiser";
  @override
  String get search => "Rechercher";
  @override
  String get settings => "Paramètres";
  @override
  String get share => "Partager";
  @override
  String get details => "Détails";
  @override
  String get open => "Ouvrir";
  @override
  String get unlock => "Déverrouiller";
  @override
  String get go => "Aller";
  @override
  String get more => "Plus d'options";
  @override
  String get undo => "Annuler";

  @override
  String get openPdf => "Ouvrir un PDF";
  @override
  String get searchDocuments => "Rechercher des documents";
  @override
  String get searchFilesHint => "Rechercher un document par nom…";
  @override
  String get sortBy => "Trier par";
  @override
  String get sortDate => "Date (Plus récents)";
  @override
  String get sortName => "Nom (A–Z)";
  @override
  String get sortSize => "Taille du fichier (Plus volumineux)";
  @override
  String get onThisDevice => "SUR CET APPAREIL";
  @override
  String get recentFiles => "FICHIERS RÉCENTS";
  @override
  String get scannedFolders => "Dossiers analysés";
  @override
  String get addFolder => "Ajouter un dossier";
  @override
  String get removeFolder => "Supprimer le dossier";
  @override
  String get welcomeTitle => "Bienvenue sur Pagelit";
  @override
  String get welcomeSubtitle =>
      "Ouvrez un fichier PDF, Word, Excel ou PowerPoint pour commencer votre lecture.\nSurlignez, annotez, recherchez, partagez ou enregistrez des pages dans la galerie.";
  @override
  String get openFirstPdf => "Ouvrir votre premier PDF";
  @override
  String get findPdfsOnDevice => "Trouver des PDF sur cet appareil";
  @override
  String get showPdfsOnDevice => "Afficher les PDF sur cet appareil";
  @override
  String get deviceAccessDescription =>
      "Pagelit peut répertorier chaque document PDF et fichier bureautique stocké sur votre téléphone, du plus récent au plus ancien. Autorisez l'accès complet au stockage ou choisissez des dossiers à analyser.";
  @override
  String get allowAccess => "Autoriser l'accès";
  @override
  String get chooseFolder => "Choisir un dossier";
  @override
  String get lookingForDocuments => "Recherche de documents…";
  @override
  String get noMatchingFiles => "Aucun fichier correspondant trouvé.";
  @override
  String get noDocumentsYet =>
      "Aucun document trouvé pour l'instant. Ajoutez un autre dossier à analyser.";
  @override
  String get fileOptions => "Options du fichier";
  @override
  String get removeFromRecents => "Supprimer des récents";
  @override
  String get fileNotFound => "FICHIER INTROUVABLE";
  @override
  String get couldNotOpenDocument => "Impossible d'ouvrir ce document.";
  @override
  String get chooseFolderPrompt =>
      "Choisissez un dossier afin que Pagelit puisse trouver vos PDF.";
  @override
  String get noCustomFolders =>
      "Aucun dossier personnalisé ajouté pour l'instant.\nAppuyez sur le bouton + pour sélectionner un dossier à analyser.";
  @override
  String scannedFoldersCount(int count) =>
      "$count dossier${count > 1 ? 's' : ''} personnalisé${count > 1 ? 's' : ''} analysé${count > 1 ? 's' : ''}";
  @override
  String get noCustomFoldersSelected => "Aucun dossier personnalisé sélectionné";

  @override
  String get justNow => "À l'instant";
  @override
  String minutesAgo(int minutes) => "Il y a $minutes min";
  @override
  String hoursAgo(int hours) => "Il y a $hours h";
  @override
  String daysAgo(int days) => "Il y a $days j";
  @override
  String pageXOfY(int page, int total, int percent, String dateOrSize) =>
      "PAGE $page SUR $total · $percent% · $dateOrSize";

  @override
  String formatBytes(int bytes) {
    if (bytes <= 0) return "0 o";
    const units = ["o", "Ko", "Mo", "Go"];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final digits = unit == 0 || value >= 100 ? 0 : 1;
    return "${value.toStringAsFixed(digits)} ${units[unit]}";
  }

  @override
  String get fileDetails => "Détails du fichier";
  @override
  String get fileName => "Nom";
  @override
  String get fileType => "Type de fichier";
  @override
  String get fileSize => "Taille";
  @override
  String get fileModified => "Dernière modification";
  @override
  String get fileLocation => "Emplacement";
  @override
  String get pdfDocumentType => "Document PDF";
  @override
  String get wordDocumentType => "Document Microsoft Word";
  @override
  String get excelSpreadsheetType => "Feuille de calcul Microsoft Excel";
  @override
  String get powerPointPresentationType => "Présentation Microsoft PowerPoint";

  @override
  String get appearance => "APPARENCE";
  @override
  String get themeSystem => "Système";
  @override
  String get themeLight => "Clair";
  @override
  String get themeDark => "Sombre";

  @override
  String get language => "LANGUE";
  @override
  String get languageSystem => "Par défaut (Système)";
  @override
  String get languageEn => "Anglais";
  @override
  String get languageFr => "Français";
  @override
  String get languageAr => "Arabe";

  @override
  String get reading => "LECTURE";
  @override
  String get keepScreenOn => "Maintenir l'écran allumé";
  @override
  String get whileDocumentIsOpen => "Pendant la consultation d'un document";
  @override
  String get pageLayout => "Disposition des pages";
  @override
  String get layoutContinuous => "Défilement continu";
  @override
  String get layoutSingle => "Page par page";
  @override
  String get scrollDirection => "Sens de défilement";
  @override
  String get scrollVertical => "Vertical";
  @override
  String get scrollHorizontal => "Horizontal";
  @override
  String get comfortMode => "Mode confort visuel & nuit";
  @override
  String get comfortNormal => "Standard";
  @override
  String get comfortSepia => "Sépia";
  @override
  String get comfortDim => "Tamisé";
  @override
  String get comfortNight => "Nuit";

  @override
  String get annotations => "ANNOTATIONS";
  @override
  String get storageAndFolders => "STOCKAGE & DOSSIERS";
  @override
  String get clearSharedCache => "Vider le cache des documents";
  @override
  String temporaryCopies(String size) => "Fichiers temporaires : $size";
  @override
  String get clearCacheTitle => "Effacer les fichiers en cache ?";
  @override
  String get clearCacheContent =>
      "Cela supprimera les copies temporaires des documents ouverts depuis d'autres applications (WhatsApp, Téléchargements, Drive). Vos fichiers d'origine sur l'appareil ne sont pas supprimés.";
  @override
  String get cacheClearedSnackbar => "Cache des documents vidé avec succès";
  @override
  String get clearRecentsTitle => "Effacer les récents et la progression";
  @override
  String get clearRecentsSubtitle =>
      "Réinitialise la liste et les positions de lecture";
  @override
  String get clearRecentsConfirmTitle => "Effacer les récents ?";
  @override
  String get clearRecentsConfirmContent =>
      "Cela supprime votre liste de fichiers récents, les documents en cache et toutes les positions de lecture enregistrées. Vos documents d'origine ne sont pas supprimés.";
  @override
  String get recentsClearedSnackbar => "Récents, cache et progression effacés";

  @override
  String get premium => "VERSION SANS PUBLICITÉ";
  @override
  String get removeAds => "Supprimer les publicités";
  @override
  String get premiumActiveSubtitle =>
      "Merci ! Les publicités sont désactivées partout.";
  @override
  String get oneTimePurchase => "Achat unique";
  @override
  String oneTimePurchaseWithPrice(String price) => "Achat unique · $price";
  @override
  String get restorePurchases => "Restaurer les achats";
  @override
  String get simulatePremium => "Simuler la version sans publicité (test)";
  @override
  String get simulatePremiumSubtitle =>
      "Activer le mode sans publicité pour les tests locaux";
  @override
  String get playBillingUnavailableTitle =>
      "Facturation Google Play indisponible";
  @override
  String get playBillingUnavailableContent =>
      "Le service Google Play n'a pas pu trouver le produit « remove_ads ».\n\nCela est normal en mode de test local ou avant la publication officielle.\n\nSouhaitez-vous activer la version sans publicité en mode test dès maintenant ?";
  @override
  String get activatePremium => "Activer la version sans publicité";
  @override
  String get premiumActivatedSnackbar =>
      "Version sans publicité activée ! Les annonces sont supprimées.";
  @override
  String get noPreviousPurchase => "Aucun achat précédent trouvé sur ce compte.";
  @override
  String get billingConnectError =>
      "Impossible de se connecter à Google Play. Veuillez vérifier votre connexion internet et les services Google Play.";
  @override
  String get billingPurchaseError =>
      "Impossible de lancer l'achat. Veuillez réessayer ultérieurement.";

  @override
  String get about => "À PROPOS";
  @override
  String get version => "Version";
  @override
  String get privacyPolicy => "Politique de confidentialité";

  @override
  String get passwordProtected => "Document protégé par mot de passe";
  @override
  String get passwordPrompt =>
      "Ce document est chiffré. Entrez le mot de passe pour l'ouvrir :";
  @override
  String get passwordHint => "Mot de passe";
  @override
  String couldNotOpenPdf(String error) =>
      "Impossible d'ouvrir le PDF : $error";
  @override
  String get tableOfContents => "Table des matières";
  @override
  String get noTableOfContents =>
      "Ce document ne comporte pas de table des matières.";
  @override
  String get goToPage => "Aller à la page";
  @override
  String get pageNumberHint => "Numéro de page";
  @override
  String get ofWord => "sur";
  @override
  String pageMustBeBetween(int count) =>
      "La page doit être comprise entre 1 et $count";
  @override
  String get searchInDocument => "Rechercher dans le document";
  @override
  String get closeSearch => "Fermer la recherche";
  @override
  String get previousMatch => "Résultat précédent";
  @override
  String get nextMatch => "Résultat suivant";
  @override
  String get noResults => "Aucun résultat trouvé";
  @override
  String get fullScreen => "Plein écran";
  @override
  String get exitFullScreen => "Quitter le plein écran";
  @override
  String get askGemini => "Consulter Gemini";
  @override
  String get askGeminiAboutPage => "Interroger Gemini à propos de cette page";
  @override
  String get comments => "Annotations & Notes";
  @override
  String get sharePdf => "Partager le PDF";
  @override
  String get rotate90 => "Faire pivoter (90°)";
  @override
  String get printDocument => "Imprimer le document";
  @override
  String get saveAnnotatedCopy => "Enregistrer une copie annotée";
  @override
  String get saveCurrentViewToGallery =>
      "Enregistrer la vue actuelle dans la galerie";
  @override
  String get toolReadPan => "Lecture / navigation";
  @override
  String get toolHighlight => "Surligner";
  @override
  String get toolUnderline => "Souligner";
  @override
  String get toolStrikethrough => "Barrer";
  @override
  String get toolSquiggly => "Ondulé";
  @override
  String get toolComment => "Ajouter une note";
  @override
  String get annotationColor => "Couleur d'annotation";
  @override
  String get deleteAnnotation => "Supprimer l'annotation";
  @override
  String get deleteComment => "Supprimer la note";
  @override
  String get addComment => "Ajouter une note";
  @override
  String get commentHint => "Écrivez une note ici…";
  @override
  String get noCommentsYet =>
      "Aucune note pour le moment. Utilisez l'outil note pour en ajouter une.";
  @override
  String get noCommentsLeft => "Plus aucune note enregistrée";
  @override
  String viewOfPageSaved(int page) =>
      "Aperçu de la page $page enregistré dans la galerie";
  @override
  String savedToPath(String path) => "Enregistré sous $path";
  @override
  String get openingDocument => "Ouverture du document…";
  @override
  String get printingNotSupported =>
      "L'impression n'est pas prise en charge sur cet appareil.";

  @override
  String get searchCellContents => "Rechercher dans les cellules...";
  @override
  String get emptyWorkbook => "Classeur vide";
  @override
  String get sheetContainsNoData => "Cette feuille ne contient aucune donnée.";
  @override
  String get copyValue => "Copier la valeur";
  @override
  String get copiedCellText =>
      "Texte de la cellule copié dans le presse-papiers";
  @override
  String get saveSheetViewToGallery => "Enregistrer la feuille dans la galerie";
  @override
  String sheetViewSaved(String sheetName) =>
      "Vue de la feuille \"$sheetName\" enregistrée dans la galerie";
  @override
  String get emptyCell => "(Vide)";
  @override
  String get dismiss => "Fermer";

  @override
  String get searchWordHint => "Rechercher dans le document...";
  @override
  String get smallerText => "Texte plus petit";
  @override
  String get largerText => "Texte plus grand";
  @override
  String get saveWordViewToGallery => "Enregistrer la vue dans la galerie";
  @override
  String get documentViewSaved => "Vue du document enregistrée dans la galerie";
  @override
  String get wordDocumentEmpty => "Ce document est vide.";

  @override
  String allSlidesCount(int count) => "Toutes les diapositives ($count)";
  @override
  String slideXOfY(int index, int total) =>
      "Diapositive $index sur $total";
  @override
  String slideNumber(int number) => "Diapositive $number";
  @override
  String get slideTitleOnly => "(Titre de la diapositive uniquement)";
  @override
  String get saveSlideToGallery => "Enregistrer la diapositive dans la galerie";
  @override
  String slideSaved(int number) =>
      "Diapositive $number enregistrée dans la galerie";
  @override
  String get saveImageToGallery => "Enregistrer l'image dans la galerie";
  @override
  String get imageSavedToGallery => "Image enregistrée dans la galerie";
  @override
  String get aspectRatioMode => "Format d'affichage (16:9)";
  @override
  String get expandedBigContainer => "Mode plein écran agrandi";
  @override
  String get searchPresentationHint =>
      "Rechercher dans la diapositive…";
  @override
  String get presentationHasNoSlides =>
      "Cette présentation ne contient aucune diapositive.";

  @override
  String get viewerNotReady => "Le visualiseur n'est pas prêt pour la capture";
  @override
  String get couldNotGenerateSnapshot =>
      "Impossible de générer la capture d'image";
  @override
  String get galleryPermissionDenied =>
      "Autorisation d'accès à la galerie refusée";
  @override
  String get savedToGallerySuccess =>
      "Enregistré dans la galerie avec succès";
  @override
  String askGeminiTitle(String title) => "Consulter Gemini : $title";
  @override
  String couldNotShare(String error) => "Impossible de partager : $error";
  @override
  String couldNotSave(String error) => "Impossible d'enregistrer : $error";
  @override
  String couldNotSaveToGallery(String error) =>
      "Impossible d'enregistrer dans la galerie : $error";
  @override
  String couldNotShareToGemini(String error) =>
      "Impossible de partager avec Gemini : $error";

  // Splash & Onboarding
  @override
  String get splashTagline => "Lecture fluide, rapide et privée";
  @override
  String get welcomeToPagelit => "Bienvenue sur Pagelit";
  @override
  String get chooseThemeTitle => "Choisissez votre thème";
  @override
  String get chooseThemeSubtitle =>
      "Sélectionnez votre style préféré. Vous pourrez le modifier à tout moment dans les Paramètres.";
  @override
  String get themeLightTitle => "Mode Clair";
  @override
  String get themeLightSubtitle => "Clair et net pour la lecture de jour";
  @override
  String get themeDarkTitle => "Mode Sombre";
  @override
  String get themeDarkSubtitle => "Agréable pour les yeux dans l'obscurité";
  @override
  String get chooseLanguageTitle => "Choisissez votre langue";
  @override
  String get chooseLanguageSubtitle =>
      "Sélectionnez votre langue d'affichage préférée.";
  @override
  String get continueButton => "Continuer";
  @override
  String get getStarted => "Commencer";
  @override
  String get stepTheme => "Thème";
  @override
  String get stepLanguage => "Langue";
  @override
  String get previous => "Précédent";
}

// -----------------------------------------------------------------------------
// Arabic (العربية)
// -----------------------------------------------------------------------------
class _AppLocalizationsAr extends AppLocalizations {
  const _AppLocalizationsAr();

  @override
  String get appTitle => "Pagelit";
  @override
  String get cancel => "إلغاء";
  @override
  String get close => "إغلاق";
  @override
  String get save => "حفظ";
  @override
  String get clear => "مسح";
  @override
  String get delete => "حذف";
  @override
  String get remove => "إزالة";
  @override
  String get retry => "إعادة المحاولة";
  @override
  String get refresh => "تحديث";
  @override
  String get search => "بحث";
  @override
  String get settings => "الإعدادات";
  @override
  String get share => "مشاركة";
  @override
  String get details => "التفاصيل";
  @override
  String get open => "فتح";
  @override
  String get unlock => "إلغاء القفل";
  @override
  String get go => "انتقال";
  @override
  String get more => "المزيد من الخيارات";
  @override
  String get undo => "تراجع";

  @override
  String get openPdf => "فتح ملف PDF";
  @override
  String get searchDocuments => "بحث في المستندات";
  @override
  String get searchFilesHint => "البحث عن الملفات بالاسم...";
  @override
  String get sortBy => "ترتيب حسب";
  @override
  String get sortDate => "التاريخ (الأحدث أولاً)";
  @override
  String get sortName => "الاسم (أ–ي)";
  @override
  String get sortSize => "حجم الملف (الأكبر أولاً)";
  @override
  String get onThisDevice => "على هذا الجهاز";
  @override
  String get recentFiles => "الملفات الأخيرة";
  @override
  String get scannedFolders => "المجلدات المفحوصة";
  @override
  String get addFolder => "إضافة مجلد";
  @override
  String get removeFolder => "إزالة المجلد";
  @override
  String get welcomeTitle => "مرحباً بك في Pagelit";
  @override
  String get welcomeSubtitle =>
      "افتح أي ملف PDF أو Word أو Excel أو PowerPoint لبدء القراءة.\nيمكنك التظليل وإضافة الملاحظات والبحث والمشاركة أو حفظ الصفحات في المعرض.";
  @override
  String get openFirstPdf => "افتح أول ملف PDF";
  @override
  String get findPdfsOnDevice => "البحث عن ملفات PDF على هذا الجهاز";
  @override
  String get showPdfsOnDevice => "عرض ملفات PDF على هذا الجهاز";
  @override
  String get deviceAccessDescription =>
      "يمكن لـ Pagelit عرض جميع مستندات PDF وملفات أوفيس المخزنة على هاتفك، بدءاً من الأحدث. يرجى منح إذن الوصول الكامل إلى التخزين أو اختيار مجلدات مخصصة.";
  @override
  String get allowAccess => "منح الإذن";
  @override
  String get chooseFolder => "اختيار مجلد";
  @override
  String get lookingForDocuments => "جارٍ البحث عن المستندات…";
  @override
  String get noMatchingFiles => "لم يتم العثور على ملفات مطابقة.";
  @override
  String get noDocumentsYet =>
      "لم يتم العثور على مستندات حتى الآن. أضف مجلداً آخر لفحصه.";
  @override
  String get fileOptions => "خيارات الملف";
  @override
  String get removeFromRecents => "إزالة من الملفات الأخيرة";
  @override
  String get fileNotFound => "الملف غير موجود";
  @override
  String get couldNotOpenDocument => "تعذر فتح هذا المستند.";
  @override
  String get chooseFolderPrompt =>
      "اختر مجلداً ليتمكن Pagelit من العثور على ملفاتك.";
  @override
  String get noCustomFolders =>
      "لم تتم إضافة مجلدات مخصصة بعد.\nاضغط على الزر + لتحديد مجلد لمسحه.";
  @override
  String scannedFoldersCount(int count) =>
      "$count مجلد${count > 1 ? 'ات' : ''} مخصص${count > 1 ? 'ة' : ''}";
  @override
  String get noCustomFoldersSelected => "لم يتم تحديد مجلدات مخصصة";

  @override
  String get justNow => "الآن";
  @override
  String minutesAgo(int minutes) => "منذ $minutes دقيقة";
  @override
  String hoursAgo(int hours) => "منذ $hours ساعة";
  @override
  String daysAgo(int days) => "منذ $days يوم";
  @override
  String pageXOfY(int page, int total, int percent, String dateOrSize) =>
      "صفحة $page من $total · $percent% · $dateOrSize";

  @override
  String formatBytes(int bytes) {
    if (bytes <= 0) return "0 بايت";
    const units = ["بايت", "ك.ب", "م.ب", "ج.ب"];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final digits = unit == 0 || value >= 100 ? 0 : 1;
    return "${value.toStringAsFixed(digits)} ${units[unit]}";
  }

  @override
  String get fileDetails => "تفاصيل الملف";
  @override
  String get fileName => "الاسم";
  @override
  String get fileType => "نوع الملف";
  @override
  String get fileSize => "حجم الملف";
  @override
  String get fileModified => "تاريخ التعديل";
  @override
  String get fileLocation => "المسار";
  @override
  String get pdfDocumentType => "مستند PDF";
  @override
  String get wordDocumentType => "مستند Microsoft Word";
  @override
  String get excelSpreadsheetType => "جدول بيانات Microsoft Excel";
  @override
  String get powerPointPresentationType => "عرض تقديمي Microsoft PowerPoint";

  @override
  String get appearance => "المظهر";
  @override
  String get themeSystem => "تلقائي (حسب النظام)";
  @override
  String get themeLight => "فاتح";
  @override
  String get themeDark => "داكن";

  @override
  String get language => "اللغة";
  @override
  String get languageSystem => "تلقائي (لغة النظام)";
  @override
  String get languageEn => "الإنجليزية";
  @override
  String get languageFr => "الفرنسية";
  @override
  String get languageAr => "العربية";

  @override
  String get reading => "القراءة";
  @override
  String get keepScreenOn => "إبقاء الشاشة مفعّلة";
  @override
  String get whileDocumentIsOpen => "أثناء قراءة المستند";
  @override
  String get pageLayout => "تخطيط الصفحات";
  @override
  String get layoutContinuous => "تمرير مستمر";
  @override
  String get layoutSingle => "صفحة تلو الأخرى";
  @override
  String get scrollDirection => "اتجاه التمرير";
  @override
  String get scrollVertical => "عمودي";
  @override
  String get scrollHorizontal => "أفقي";
  @override
  String get comfortMode => "وضع القراءة المريحة والداكن";
  @override
  String get comfortNormal => "افتراضي";
  @override
  String get comfortSepia => "سيبيا (دافئ)";
  @override
  String get comfortDim => "خافت";
  @override
  String get comfortNight => "ليلي";

  @override
  String get annotations => "التظليل والملاحظات";
  @override
  String get storageAndFolders => "التخزين والمجلدات";
  @override
  String get clearSharedCache => "مسح ذاكرة التخزين المؤقت للمستندات";
  @override
  String temporaryCopies(String size) => "الملفات المؤقتة: $size";
  @override
  String get clearCacheTitle => "مسح الملفات المؤقتة؟";
  @override
  String get clearCacheContent =>
      "سيؤدي هذا إلى حذف النسخ المؤقتة للمستندات المفتوحة من تطبيقات أخرى (مثل واتساب والتنزيلات ودرايف). لن تُحذف ملفاتك الأصلية على الجهاز.";
  @override
  String get cacheClearedSnackbar => "تم مسح ذاكرة التخزين المؤقت بنجاح";
  @override
  String get clearRecentsTitle => "مسح سجل الملفات الأخيرة والتقدم";
  @override
  String get clearRecentsSubtitle =>
      "حذف قائمة الملفات الأخيرة ومواضع القراءة المحفوظة";
  @override
  String get clearRecentsConfirmTitle => "مسح الملفات الأخيرة؟";
  @override
  String get clearRecentsConfirmContent =>
      "سيؤدي هذا إلى حذف قائمة الملفات الأخيرة والنسخ المؤقتة وجميع مواضع القراءة المحفوظة. لن تتأثر ملفاتك الأصلية نهائياً.";
  @override
  String get recentsClearedSnackbar =>
      "تم مسح الملفات الأخيرة وذاكرة التخزين وسجل القراءة";

  @override
  String get premium => "النسخة المميزة (بدون إعلانات)";
  @override
  String get removeAds => "إزالة الإعلانات";
  @override
  String get premiumActiveSubtitle => "شكراً لك! تم إيقاف الإعلانات بالكامل.";
  @override
  String get oneTimePurchase => "شراء لمرة واحدة";
  @override
  String oneTimePurchaseWithPrice(String price) => "شراء لمرة واحدة · $price";
  @override
  String get restorePurchases => "استعادة المشتريات السابقة";
  @override
  String get simulatePremium => "تجربة النسخة المميزة (وضع الاختبار)";
  @override
  String get simulatePremiumSubtitle =>
      "تفعيل الوضع الخالي من الإعلانات لأغراض الاختبار والتطوير";
  @override
  String get playBillingUnavailableTitle => "خدمة الدفع عبر Google Play غير متوفرة";
  @override
  String get playBillingUnavailableContent =>
      "تعذر على خدمة Google Play العثور على منتج إزالة الإعلانات.\n\nهذا أمر طبيعي أثناء الاختبار والتطوير المحلي.\n\nهل ترغب في تفعيل النسخة المميزة في وضع الاختبار الآن؟";
  @override
  String get activatePremium => "تفعيل النسخة المميزة";
  @override
  String get premiumActivatedSnackbar =>
      "تم تفعيل النسخة المميزة! تمت إزالة الإعلانات.";
  @override
  String get noPreviousPurchase => "لم يتم العثور على أي مشتريات سابقة.";
  @override
  String get billingConnectError =>
      "تعذر الاتصال بـ Google Play. يرجى التحقق من اتصالك بالإنترنت وخدمات Google Play.";
  @override
  String get billingPurchaseError =>
      "تعذر إتمام عملية الشراء في الوقت الحالي. يرجى المحاولة لاحقاً.";

  @override
  String get about => "حول التطبيق";
  @override
  String get version => "رقم الإصدار";
  @override
  String get privacyPolicy => "سياسة الخصوصية";

  @override
  String get passwordProtected => "مستند محمي بكلمة مرور";
  @override
  String get passwordPrompt =>
      "هذا المستند محمي بتشفير. أدخل كلمة المرور لفتحه:";
  @override
  String get passwordHint => "كلمة المرور";
  @override
  String couldNotOpenPdf(String error) => "تعذر فتح ملف PDF: $error";
  @override
  String get tableOfContents => "جدول المحتويات";
  @override
  String get noTableOfContents => "لا يحتوي هذا المستند على جدول محتويات.";
  @override
  String get goToPage => "الانتقال إلى صفحة";
  @override
  String get pageNumberHint => "رقم الصفحة";
  @override
  String get ofWord => "من";
  @override
  String pageMustBeBetween(int count) =>
      "يجب أن يكون رقم الصفحة بين 1 و $count";
  @override
  String get searchInDocument => "البحث في المستند";
  @override
  String get closeSearch => "إغلاق شريط البحث";
  @override
  String get previousMatch => "النتيجة السابقة";
  @override
  String get nextMatch => "النتيجة التالية";
  @override
  String get noResults => "لم يتم العثور على نتائج";
  @override
  String get fullScreen => "ملء الشاشة";
  @override
  String get exitFullScreen => "الخروج من ملء الشاشة";
  @override
  String get askGemini => "استشارة Gemini الذكي";
  @override
  String get askGeminiAboutPage => "اسأل الذكاء الاصطناعي Gemini عن هذه الصفحة";
  @override
  String get comments => "الملاحظات والتعليقات";
  @override
  String get sharePdf => "مشاركة مستند PDF";
  @override
  String get rotate90 => "تدوير (90 درجة)";
  @override
  String get printDocument => "طباعة المستند";
  @override
  String get saveAnnotatedCopy => "حفظ نسخة مع التعديلات والملاحظات";
  @override
  String get saveCurrentViewToGallery => "حفظ الصفحة المعروضة في المعرض";
  @override
  String get toolReadPan => "قراءة وتصفح";
  @override
  String get toolHighlight => "تظليل";
  @override
  String get toolUnderline => "تسطير";
  @override
  String get toolStrikethrough => "يتوسطه خط";
  @override
  String get toolSquiggly => "خط متعرج";
  @override
  String get toolComment => "إضافة ملاحظة";
  @override
  String get annotationColor => "لون التظليل";
  @override
  String get deleteAnnotation => "حذف التظليل";
  @override
  String get deleteComment => "حذف الملاحظة";
  @override
  String get addComment => "إضافة ملاحظة";
  @override
  String get commentHint => "اكتب ملاحظتك التوضيحية هنا…";
  @override
  String get noCommentsYet =>
      "لا توجد ملاحظات بعد. انقر بأداة الملاحظة لإضافة تعليق.";
  @override
  String get noCommentsLeft => "تم حذف جميع الملاحظات";
  @override
  String viewOfPageSaved(int page) => "تم حفظ صورة الصفحة $page في المعرض";
  @override
  String savedToPath(String path) => "تم الحفظ في $path";
  @override
  String get openingDocument => "جارٍ فتح المستند وتجهيزه…";
  @override
  String get printingNotSupported => "الطباعة غير مدعومة على هذا الجهاز.";

  @override
  String get searchCellContents => "البحث في محتويات الخلايا...";
  @override
  String get emptyWorkbook => "مصنف فارغ";
  @override
  String get sheetContainsNoData => "لا تحتوي هذه الورقة على أي بيانات.";
  @override
  String get copyValue => "نسخ القيمة";
  @override
  String get copiedCellText => "تم نسخ نص الخلية إلى الحافظة بنجاح";
  @override
  String get saveSheetViewToGallery => "حفظ عرض الورقة في المعرض";
  @override
  String sheetViewSaved(String sheetName) =>
      "تم حفظ عرض الورقة \"$sheetName\" في المعرض";
  @override
  String get emptyCell => "(فارغ)";
  @override
  String get dismiss => "إغلاق";

  @override
  String get searchWordHint => "البحث في المستند...";
  @override
  String get smallerText => "تصغير النص";
  @override
  String get largerText => "تكبير النص";
  @override
  String get saveWordViewToGallery => "حفظ العرض في المعرض";
  @override
  String get documentViewSaved => "تم حفظ عرض المستند في المعرض بنجاح";
  @override
  String get wordDocumentEmpty => "هذا المستند فارغ ولا يحتوي على نصوص.";

  @override
  String allSlidesCount(int count) => "جميع الشرائح ($count)";
  @override
  String slideXOfY(int index, int total) => "شريحة $index من $total";
  @override
  String slideNumber(int number) => "الشريحة $number";
  @override
  String get slideTitleOnly => "(عنوان الشريحة فقط)";
  @override
  String get saveSlideToGallery => "حفظ الشريحة في المعرض";
  @override
  String slideSaved(int number) => "تم حفظ الشريحة $number في المعرض بنجاح";
  @override
  String get saveImageToGallery => "حفظ الصورة في المعرض";
  @override
  String get imageSavedToGallery => "تم حفظ الصورة في المعرض بنجاح";
  @override
  String get aspectRatioMode => "وضع نسبة العرض (16:9)";
  @override
  String get expandedBigContainer => "وضع الحجم الكامل";
  @override
  String get searchPresentationHint => "البحث في نص الشرائح...";
  @override
  String get presentationHasNoSlides => "لا يحتوي هذا العرض التقديمي على شرائح.";

  @override
  String get viewerNotReady => "عارض الملفات غير جاهز للالتقاط حالياً";
  @override
  String get couldNotGenerateSnapshot => "تعذر إنشاء لقطة للصورة";
  @override
  String get galleryPermissionDenied => "تم رفض إذن الوصول إلى المعرض";
  @override
  String get savedToGallerySuccess => "تم الحفظ في المعرض بنجاح";
  @override
  String askGeminiTitle(String title) => "اسأل Gemini: $title";
  @override
  String couldNotShare(String error) => "تعذر مشاركة الملف: $error";
  @override
  String couldNotSave(String error) => "تعذر حفظ الملف: $error";
  @override
  String couldNotSaveToGallery(String error) =>
      "تعذر الحفظ في المعرض: $error";
  @override
  String couldNotShareToGemini(String error) =>
      "تعذر إرسال الملف إلى Gemini: $error";

  // Splash & Onboarding
  @override
  String get splashTagline => "قراءة سلسة، سريعة وبخصوصية تامة";
  @override
  String get welcomeToPagelit => "مرحباً بك في Pagelit";
  @override
  String get chooseThemeTitle => "اختر المظهر المفضل";
  @override
  String get chooseThemeSubtitle =>
      "اختر الوضع الفاتح أو الداكن. يمكنك تغيير ذلك لاحقاً في أي وقت من الإعدادات.";
  @override
  String get themeLightTitle => "الوضع الفاتح";
  @override
  String get themeLightSubtitle => "مظهر ناصع ومريح للقراءة النهارية";
  @override
  String get themeDarkTitle => "الوضع الداكن";
  @override
  String get themeDarkSubtitle => "مريح وهادئ للعينين في الإضاءة الخافتة";
  @override
  String get chooseLanguageTitle => "اختر لغة التطبيق";
  @override
  String get chooseLanguageSubtitle =>
      "حدد لغة العرض التي تفضل استخدام التطبيق بها.";
  @override
  String get continueButton => "متابعة";
  @override
  String get getStarted => "ابدأ القراءة";
  @override
  String get stepTheme => "المظهر";
  @override
  String get stepLanguage => "اللغة";
  @override
  String get previous => "السابق";
}
# Pagelit website (GitHub Pages)

Static site living in the docs/ folder so it can be deployed directly
from this repository with no extra build step.

## How to publish on GitHub Pages
1. Push this repository to GitHub.
2. Repository → Settings → Pages.
3. Source: "Deploy from a branch".
4. Branch: main → folder /docs.
5. Save. Your site will be live at:
   https://<your-username>.github.io/pagelit/

All internal links are relative (no leading slash), so the site works at any
base path — root domain OR project folder — without configuration changes.

## Custom domain (optional)
Add a file CNAME containing your domain (e.g. pagelit.yoursite.com)
and point DNS to GitHub Pages. Then update the <meta property="og:...">
image URL in index.html / privacy.html to the absolute URL.

## Files
- index.html         landing page
- privacy.html       Play-Console-ready privacy policy
- style.css          design system
- favicon.svg
- assets/logo/       app icon used on the site and as og:image

## Brand
Colours in style.css are copied verbatim from lib/theme/app_theme.dart
(AppPalette) so the site matches the app exactly. If the app's palette
changes, update style.css and favicon.svg in the same commit.

    --signal      #E5453B   the single accent (the glyph red)
    --signal-deep #C33A31
    --signal-wash #FBE6E3
    --paper       #FBF8F4   light background
    --card        #FFFFFF
    --hairline    #E9E2D8
    --ink         #17161C   light-mode text
    --muted       #6E6A77
    --wash        #F4F0E8
    --amber       #FFD93D   the highlighter swipe from the icon

The app's dark ("night") palette is deliberately not used here - the site
is light-only.

## Customise before publishing
- Contact email lives in privacy.html (update both @ links if you change it).
- The Google Play badge button points to
  https://play.google.com/store/apps/details?id=com.the356company.pagelit
  which resolves once the app is published.
- lib/screens/settings_screen.dart has _privacyUrl pointing at this page.
  If the Pages URL changes (renamed repo, custom domain), update it there too.

# deploy_web.ps1 — builds PhysioConnect for the web and pushes to GitHub Pages.
#
# Prerequisites:
#   1. Create the GitHub repo "physioconnect-app" (public, no README) at
#      https://github.com/new  — do this once before the first run.
#   2. Install Git for Windows (already present if you are using this project).
#
# Usage (from project root):
#   .\scripts\deploy_web.ps1
#
# The PWA will be live at:
#   https://jihadzhour-dot.github.io/physioconnect-app/

$ErrorActionPreference = "Stop"

$REPO_URL  = "https://github.com/jihadzhour-dot/physioconnect-app.git"
$BASE_HREF = "/physioconnect-app/"
$BUILD_DIR = "build\web"

Write-Host ""
Write-Host "=== PhysioConnect PWA Deploy ===" -ForegroundColor Cyan
Write-Host ""

# ── 1. Build ──────────────────────────────────────────────────────────────────
Write-Host "[1/3] Building release web (base-href $BASE_HREF)..." -ForegroundColor Yellow
flutter build web --release --base-href $BASE_HREF
Write-Host "      Build complete." -ForegroundColor Green

# ── 2. Init a throwaway git repo in the build output ─────────────────────────
Write-Host "[2/3] Preparing git repo in $BUILD_DIR..." -ForegroundColor Yellow
Push-Location $BUILD_DIR
try {
    git init -b gh-pages
    git add -A
    git commit -m "deploy: PhysioConnect PWA $(Get-Date -Format 'yyyy-MM-dd HH:mm')"

    # ── 3. Force-push to gh-pages branch ─────────────────────────────────────
    Write-Host "[3/3] Pushing to $REPO_URL (branch: gh-pages)..." -ForegroundColor Yellow
    git remote add origin $REPO_URL
    git push --force origin gh-pages
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "=== Done! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Your PWA will be live in ~60 seconds at:" -ForegroundColor Cyan
Write-Host "  https://jihadzhour-dot.github.io/physioconnect-app/" -ForegroundColor White
Write-Host ""
Write-Host "Reminder — one-time manual steps (see deploy instructions):" -ForegroundColor Yellow
Write-Host "  * GitHub Pages: Settings -> Pages -> Branch: gh-pages / root"
Write-Host "  * Supabase: Authentication -> URL Config -> add the Pages URL"
Write-Host ""

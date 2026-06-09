# Run this AFTER saving assets/images/logo.png
# Generates windows/runner/resources/app_icon.ico + badge PNGs

Add-Type -AssemblyName System.Drawing

$src = Join-Path $PSScriptRoot "assets\images\logo.png"
if (-not (Test-Path $src)) {
    Write-Error "logo.png not found at $src — save the image there first."
    exit 1
}

$outDir = Join-Path $PSScriptRoot "windows\runner\resources"

# ── Helper: resize and save PNG ───────────────────────────────────────────────
function Save-Png($size, $outPath) {
    $orig = [System.Drawing.Image]::FromFile($src)
    $bmp  = New-Object System.Drawing.Bitmap($size, $size)
    $g    = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($orig, 0, 0, $size, $size)
    $g.Dispose()
    $orig.Dispose()
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Saved $outPath"
}

# ── Badge PNGs (Windows Store / notification badges) ─────────────────────────
Save-Png 16  (Join-Path $outDir "badge_logo_16.png")
Save-Png 24  (Join-Path $outDir "badge_logo_24.png")
Save-Png 32  (Join-Path $outDir "badge_logo_32.png")
Save-Png 48  (Join-Path $outDir "badge_logo_48.png")

# ── ICO file (multi-resolution: 16, 32, 48, 64, 128, 256) ────────────────────
$sizes    = @(16, 32, 48, 64, 128, 256)
$icoPath  = Join-Path $outDir "app_icon.ico"
$stream   = New-Object System.IO.MemoryStream

$pngs = foreach ($sz in $sizes) {
    $bmp = New-Object System.Drawing.Bitmap($sz, $sz)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $orig = [System.Drawing.Image]::FromFile($src)
    $g.DrawImage($orig, 0, 0, $sz, $sz)
    $g.Dispose(); $orig.Dispose()
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $ms
}

# ICO header
$writer = New-Object System.IO.BinaryWriter($stream)
$writer.Write([uint16]0)          # reserved
$writer.Write([uint16]1)          # type: icon
$writer.Write([uint16]$sizes.Count)

# Calculate offsets — header(6) + directory(16 * n) + data
$dataOffset = 6 + 16 * $sizes.Count
$offsets = @()
foreach ($ms in $pngs) {
    $offsets += $dataOffset
    $dataOffset += $ms.Length
}

# Directory entries
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $sz = $sizes[$i]
    $writer.Write([byte]$(if ($sz -ge 256) { 0 } else { $sz }))  # width
    $writer.Write([byte]$(if ($sz -ge 256) { 0 } else { $sz }))  # height
    $writer.Write([byte]0)    # color count
    $writer.Write([byte]0)    # reserved
    $writer.Write([uint16]1)  # color planes
    $writer.Write([uint16]32) # bits per pixel
    $writer.Write([uint32]$pngs[$i].Length)
    $writer.Write([uint32]$offsets[$i])
}

foreach ($ms in $pngs) {
    $writer.Write($ms.ToArray())
    $ms.Dispose()
}

[System.IO.File]::WriteAllBytes($icoPath, $stream.ToArray())
$writer.Dispose(); $stream.Dispose()
Write-Host "Saved $icoPath"
Write-Host "`nDone! Run 'flutter build windows' to apply the new icon."

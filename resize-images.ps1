# PowerShell Script to Resize Images
# Resizes images so the longest edge is 2000px while maintaining aspect ratio
# Requires: Windows with built-in .NET System.Drawing

param(
    [string]$SourceFolder = "images",
    [string]$OutputFolder = "images_resized",
    [int]$MaxSize = 2000,
    [switch]$Overwrite = $false
)

# Load System.Drawing assembly
Add-Type -AssemblyName System.Drawing

# Create output folder if it doesn't exist
if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
    Write-Host "Created output folder: $OutputFolder" -ForegroundColor Green
}

# Get all image files
$imageExtensions = @('.jpg', '.jpeg', '.png', '.bmp', '.gif', '.JPG', '.JPEG', '.PNG', '.BMP', '.GIF')
$imageFiles = Get-ChildItem -Path $SourceFolder -File | Where-Object {
    $imageExtensions -contains $_.Extension
}

if ($imageFiles.Count -eq 0) {
    Write-Host "No images found in '$SourceFolder' folder." -ForegroundColor Yellow
    exit
}

Write-Host ""
Write-Host "Found $($imageFiles.Count) images to process" -ForegroundColor Cyan
Write-Host "Max dimension: $MaxSize px" -ForegroundColor Cyan
Write-Host "Output folder: $OutputFolder" -ForegroundColor Cyan
Write-Host ""

$processed = 0
$skipped = 0
$errors = 0

foreach ($file in $imageFiles) {
    try {
        $outputPath = Join-Path $OutputFolder $file.Name

        # Skip if output file exists and not overwriting
        if ((Test-Path $outputPath) -and -not $Overwrite) {
            Write-Host "Skipped: $($file.Name) (already exists)" -ForegroundColor Yellow
            $skipped++
            continue
        }

        # Load the image
        $img = [System.Drawing.Image]::FromFile($file.FullName)

        $originalWidth = $img.Width
        $originalHeight = $img.Height

        # Check if resizing is needed
        if ($originalWidth -le $MaxSize -and $originalHeight -le $MaxSize) {
            # Image is already smaller, just copy it
            Copy-Item -Path $file.FullName -Destination $outputPath -Force
            Write-Host "Copied: $($file.Name) (already $originalWidth x $originalHeight px)" -ForegroundColor Gray
            $img.Dispose()
            $processed++
            continue
        }

        # Calculate new dimensions
        if ($originalWidth -gt $originalHeight) {
            # Landscape or square
            $newWidth = $MaxSize
            $newHeight = [int](($originalHeight / $originalWidth) * $MaxSize)
        } else {
            # Portrait
            $newHeight = $MaxSize
            $newWidth = [int](($originalWidth / $originalHeight) * $MaxSize)
        }

        # Create new bitmap with calculated dimensions
        $resizedImg = New-Object System.Drawing.Bitmap($newWidth, $newHeight)
        $graphics = [System.Drawing.Graphics]::FromImage($resizedImg)

        # Set high quality rendering
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

        # Draw resized image
        $graphics.DrawImage($img, 0, 0, $newWidth, $newHeight)

        # Save with appropriate encoder
        $extension = $file.Extension.ToLower()
        if ($extension -eq '.jpg' -or $extension -eq '.jpeg') {
            # Use JPEG encoder with quality setting
            $jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
            $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
            $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 90)
            $resizedImg.Save($outputPath, $jpegCodec, $encoderParams)
        } else {
            # Save with original format
            $resizedImg.Save($outputPath)
        }

        # Cleanup
        $graphics.Dispose()
        $resizedImg.Dispose()
        $img.Dispose()

        $resizeInfo = "$originalWidth x $originalHeight -> $newWidth x $newHeight"
        Write-Host "Resized: $($file.Name) | $resizeInfo" -ForegroundColor Green
        $processed++

    } catch {
        Write-Host "Error processing $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
        $errors++
        if ($img) { $img.Dispose() }
    }
}

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "Processing Complete!" -ForegroundColor Green
Write-Host "Processed: $processed" -ForegroundColor Green
if ($skipped -gt 0) { Write-Host "Skipped: $skipped" -ForegroundColor Yellow }
if ($errors -gt 0) { Write-Host "Errors: $errors" -ForegroundColor Red }
Write-Host "=======================================" -ForegroundColor Cyan

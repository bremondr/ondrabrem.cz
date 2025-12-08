param(
    [string]$SourceRoot = "originals",
    [string]$DestinationFolder = "images",
    [int]$MaxDimension = 2000,
    [switch]$OverwriteExisting
)

$supportedExtensions = @('.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp')

if (-not (Test-Path -Path $SourceRoot)) {
    Write-Host "Source folder '$SourceRoot' does not exist." -ForegroundColor Red
    exit 1
}

$sourceRootFull = (Resolve-Path -Path $SourceRoot).ProviderPath
if (-not $sourceRootFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
    $sourceRootFull += [System.IO.Path]::DirectorySeparatorChar
}

if (-not (Test-Path -Path $DestinationFolder)) {
    New-Item -ItemType Directory -Path $DestinationFolder | Out-Null
    Write-Host "Created destination folder '$DestinationFolder'." -ForegroundColor Green
}

$destinationFull = (Resolve-Path -Path $DestinationFolder).ProviderPath
if (-not $destinationFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
    $destinationFull += [System.IO.Path]::DirectorySeparatorChar
}

$allImages = Get-ChildItem -Path $sourceRootFull -File -Recurse | Where-Object {
    $supportedExtensions -contains $_.Extension.ToLowerInvariant()
} | Sort-Object FullName

if ($allImages.Count -eq 0) {
    Write-Host "No supported image files found under '$SourceRoot'." -ForegroundColor Yellow
    exit 0
}

try {
    Add-Type -AssemblyName System.Drawing
} catch {
    Write-Host "Failed to load System.Drawing. Run this script on Windows PowerShell or install required components." -ForegroundColor Red
    exit 1
}

function ConvertTo-WebSafeBase {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }

    $normalized = $Value.Normalize([System.Text.NormalizationForm]::FormD)
    $builder = New-Object System.Text.StringBuilder
    foreach ($char in $normalized.ToCharArray()) {
        if ([System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($char) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($char)
        }
    }

    $clean = $builder.ToString().ToLowerInvariant()
    $clean = [System.Text.RegularExpressions.Regex]::Replace($clean, "[^a-z0-9]+", "-")
    $clean = [System.Text.RegularExpressions.Regex]::Replace($clean, "-+", "-").Trim('-')
    return $clean
}

function Normalize-Keyword {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $keyword = $Value -replace '[_-]+', ' '
    $keyword = [System.Text.RegularExpressions.Regex]::Replace($keyword, '\s+', ' ').Trim()
    return $keyword
}

function Get-KeywordsFromPath {
    param(
        [string]$RootPath,
        [string]$FileDirectory
    )

    if ([string]::IsNullOrWhiteSpace($FileDirectory)) {
        return @()
    }

    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    if (-not $FileDirectory.StartsWith($RootPath, $comparison)) {
        return @()
    }

    $relative = $FileDirectory.Substring($RootPath.Length).TrimStart('\','/')
    if ([string]::IsNullOrWhiteSpace($relative)) {
        return @()
    }

    $segments = $relative -split '[\\/]' | Where-Object { $_ -ne '' }
    $keywords = @()
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($segment in $segments) {
        $keyword = Normalize-Keyword -Value $segment
        if ($keyword -and $seen.Add($keyword)) {
            $keywords += $keyword
        }
    }

    return $keywords
}

function Resolve-TargetFileName {
    param(
        [string]$BaseName,
        [string]$Extension,
        [string]$DestinationPath,
        [System.Collections.Generic.HashSet[string]]$UsedNames
    )

    if ([string]::IsNullOrWhiteSpace($BaseName)) {
        $BaseName = "image"
    }

    $desired = "$BaseName$Extension"
    $targetPath = Join-Path $DestinationPath $desired

    if (-not $UsedNames.Contains($desired)) {
        $null = $UsedNames.Add($desired)
        return [PSCustomObject]@{
            Name           = $desired
            ExistsOnDisk   = (Test-Path -Path $targetPath)
            AutoRenamed    = $false
        }
    }

    if (Test-Path -Path $targetPath) {
        return [PSCustomObject]@{
            Name           = $desired
            ExistsOnDisk   = $true
            AutoRenamed    = $false
        }
    }

    $counter = 1
    while ($true) {
        $candidate = "{0}-{1}{2}" -f $BaseName, $counter, $Extension
        $candidatePath = Join-Path $DestinationPath $candidate
        if (-not $UsedNames.Contains($candidate) -and -not (Test-Path -Path $candidatePath)) {
            $null = $UsedNames.Add($candidate)
            return [PSCustomObject]@{
                Name           = $candidate
                ExistsOnDisk   = $false
                AutoRenamed    = $true
            }
        }
        $counter++
    }
}

function Merge-Keywords {
    param(
        [object]$Existing,
        [string[]]$Additional
    )

    $merged = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    if ($Existing) {
        foreach ($item in $Existing) {
            if (-not [string]::IsNullOrWhiteSpace($item)) {
                $null = $merged.Add($item)
            }
        }
    }

    foreach ($item in $Additional) {
        if (-not [string]::IsNullOrWhiteSpace($item)) {
            $null = $merged.Add($item)
        }
    }

    return $merged.ToArray()
}

function Save-ResizedImage {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [int]$MaxDim
    )

    $img = $null
    $resizedImg = $null
    $graphics = $null

    try {
        $img = [System.Drawing.Image]::FromFile($SourcePath)
        $originalWidth = $img.Width
        $originalHeight = $img.Height

        if ($originalWidth -le $MaxDim -and $originalHeight -le $MaxDim) {
            Copy-Item -Path $SourcePath -Destination $DestinationPath -Force
            return "copied"
        }

        if ($originalWidth -ge $originalHeight) {
            $newWidth = $MaxDim
            $newHeight = [int][Math]::Round(($originalHeight / $originalWidth) * $MaxDim)
        } else {
            $newHeight = $MaxDim
            $newWidth = [int][Math]::Round(($originalWidth / $originalHeight) * $MaxDim)
        }

        $resizedImg = New-Object System.Drawing.Bitmap($newWidth, $newHeight)
        $graphics = [System.Drawing.Graphics]::FromImage($resizedImg)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.DrawImage($img, 0, 0, $newWidth, $newHeight)

        $extension = [System.IO.Path]::GetExtension($DestinationPath).ToLowerInvariant()
        if ($extension -eq '.jpg' -or $extension -eq '.jpeg') {
            $jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
            $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
            $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 90)
            $resizedImg.Save($DestinationPath, $jpegCodec, $encoderParams)
        } else {
            $resizedImg.Save($DestinationPath)
        }

        return "resized"
    } finally {
        if ($graphics) { $graphics.Dispose() }
        if ($resizedImg) { $resizedImg.Dispose() }
        if ($img) { $img.Dispose() }
    }
}

$usedNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
Get-ChildItem -Path $destinationFull -File | ForEach-Object {
    $null = $usedNames.Add($_.Name)
}

$jsonPath = Join-Path $destinationFull "images.json"
$jsonData = $null

if (Test-Path -Path $jsonPath) {
    try {
        $jsonRaw = Get-Content -Path $jsonPath -Raw
        if ($jsonRaw.Trim().Length -gt 0) {
            $jsonData = $jsonRaw | ConvertFrom-Json
        }
    } catch {
        Write-Host "Existing images.json could not be parsed. Aborting to avoid data loss." -ForegroundColor Red
        exit 1
    }
}

if (-not $jsonData) {
    $jsonData = [PSCustomObject]@{ images = @() }
}
if (-not $jsonData.images) {
    $jsonData | Add-Member -NotePropertyName images -NotePropertyValue @()
}

$imageList = New-Object System.Collections.Generic.List[object]
$existingMap = @{}
foreach ($entry in $jsonData.images) {
    $imageList.Add($entry) | Out-Null
    if ($entry.file) {
        $existingMap[$entry.file] = $entry
    }
}

$processedCount = 0
$resizedCount = 0
$copiedCount = 0
$skippedCount = 0
$overwrittenCount = 0
$errorCount = 0
$newJsonEntries = 0
$updatedJsonEntries = 0

Write-Host "Processing $($allImages.Count) images from '$SourceRoot'..." -ForegroundColor Cyan

foreach ($file in $allImages) {
    $keywords = Get-KeywordsFromPath -RootPath $sourceRootFull -FileDirectory $file.DirectoryName
    $webSafeBase = ConvertTo-WebSafeBase -Value ($file.BaseName)
    if (-not $webSafeBase) {
        $webSafeBase = "image"
    }
    $extension = $file.Extension.ToLowerInvariant()

    $nameResolution = Resolve-TargetFileName -BaseName $webSafeBase -Extension $extension -DestinationPath $destinationFull -UsedNames $usedNames
    $targetName = $nameResolution.Name
    $targetPath = Join-Path $destinationFull $targetName

    $fileAvailable = $false

    if ($nameResolution.ExistsOnDisk -and -not $OverwriteExisting) {
        Write-Host "[SKIP] $targetName already exists. Use -OverwriteExisting to replace it." -ForegroundColor Yellow
        $skippedCount++
        $fileAvailable = $true
    } else {
        try {
            $result = Save-ResizedImage -SourcePath $file.FullName -DestinationPath $targetPath -MaxDim $MaxDimension
            $processedCount++
            if ($result -eq "resized") {
                $resizedCount++
                Write-Host "[RESIZE] $targetName" -ForegroundColor Green
            } else {
                $copiedCount++
                Write-Host "[COPY] $targetName (already <= $MaxDimension px)" -ForegroundColor Gray
            }

            if ($nameResolution.ExistsOnDisk -and $OverwriteExisting) {
                $overwrittenCount++
            } elseif ($nameResolution.AutoRenamed) {
                Write-Host "          -> renamed to avoid conflict" -ForegroundColor DarkGray
            }

            $fileAvailable = $true
        } catch {
            Write-Host "[ERROR] Failed to process '$($file.FullName)': $($_.Exception.Message)" -ForegroundColor Red
            $errorCount++
        }
    }

    if (-not $fileAvailable) {
        continue
    }

    $entry = $null
    if ($existingMap.ContainsKey($targetName)) {
        $entry = $existingMap[$targetName]
        $updatedJsonEntries++
    } else {
        $entry = [PSCustomObject]@{
            file     = $targetName
            name     = [System.IO.Path]::GetFileNameWithoutExtension($targetName)
            keywords = @()
        }
        $imageList.Add($entry) | Out-Null
        $existingMap[$targetName] = $entry
        $newJsonEntries++
    }

    if (-not $entry.name -or -not $entry.name.Trim()) {
        $entry.name = [System.IO.Path]::GetFileNameWithoutExtension($targetName)
    }

    $entry.keywords = Merge-Keywords -Existing $entry.keywords -Additional $keywords
}

$jsonData.images = $imageList.ToArray()
$jsonData | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "Finished processing originals." -ForegroundColor Green
Write-Host "Processed (resized or copied): $processedCount" -ForegroundColor Green
Write-Host "  - Resized: $resizedCount" -ForegroundColor Green
Write-Host "  - Copied (no resizing needed): $copiedCount" -ForegroundColor Green
if ($overwrittenCount -gt 0) { Write-Host "  - Overwritten existing files: $overwrittenCount" -ForegroundColor Yellow }
if ($skippedCount -gt 0) { Write-Host "Skipped existing files: $skippedCount" -ForegroundColor Yellow }
if ($errorCount -gt 0) { Write-Host "Errors: $errorCount" -ForegroundColor Red }
Write-Host "JSON entries - Added: $newJsonEntries, Updated: $updatedJsonEntries" -ForegroundColor Cyan
Write-Host "Output folder: $DestinationFolder" -ForegroundColor Cyan
Write-Host "JSON file: $jsonPath" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

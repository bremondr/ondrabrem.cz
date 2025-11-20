param(
    [string]$EventName,
    [string]$FolderPath,
    [int]$MaxDimension = 1920
)

if (-not $EventName -or -not $FolderPath) {
    Write-Host "Usage: .\add-event.ps1 -EventName 'Event Name' -FolderPath 'path/to/folder' [-MaxDimension 1920]"
    exit
}

# Function to convert filename to web-safe format
function ConvertTo-WebSafeFilename {
    param([string]$FileName)
    $name = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $ext = [System.IO.Path]::GetExtension($FileName)
    
    # Replace special characters, spaces, and accents with safe versions
    $name = [System.Text.RegularExpressions.Regex]::Replace($name, '[áäâàã]', 'a')
    $name = [System.Text.RegularExpressions.Regex]::Replace($name, '[éëêè]', 'e')
    $name = [System.Text.RegularExpressions.Regex]::Replace($name, '[íïîì]', 'i')
    $name = [System.Text.RegularExpressions.Regex]::Replace($name, '[óöôòõ]', 'o')
    $name = [System.Text.RegularExpressions.Regex]::Replace($name, '[úüûù]', 'u')
    $name = [System.Text.RegularExpressions.Regex]::Replace($name, '[ýÿ]', 'y')
    $name = [System.Text.RegularExpressions.Regex]::Replace($name, '[ç]', 'c')
    $name = [System.Text.RegularExpressions.Regex]::Replace($name, '[ñ]', 'n')
    $name = [System.Text.RegularExpressions.Regex]::Replace($name, '[š]', 's')
    $name = [System.Text.RegularExpressions.Regex]::Replace($name, '[ž]', 'z')
    
    # Replace spaces and underscores with hyphens, remove other special characters
    $name = [System.Text.RegularExpressions.Regex]::Replace($name, '[\s_]+', '-')
    $name = [System.Text.RegularExpressions.Regex]::Replace($name, '[^a-z0-9\-]', '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $name = [System.Text.RegularExpressions.Regex]::Replace($name, '-+', '-')
    $name = $name.Trim('-').ToLower()
    
    return "$name$ext"
}

# Function to resize and optimize image
function Resize-Image {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [int]$MaxDim
    )
    
    try {
        # Try using ffmpeg if available (most reliable)
        $ffmpegPath = Get-Command ffmpeg -ErrorAction SilentlyContinue
        if ($ffmpegPath) {
            $scaleFilter = "scale=min($($MaxDim)\,iw):min($($MaxDim)\,ih):force_original_aspect_ratio=decrease"
            & ffmpeg -i $SourcePath -vf $scaleFilter -q:v 5 $DestinationPath -y 2>$null
            
            if (Test-Path $DestinationPath) {
                Write-Host "  Resized (ffmpeg): $([System.IO.Path]::GetFileName($SourcePath))"
                return
            }
        }
        
        # Try using ImageMagick if available
        $magickPath = Get-Command magick -ErrorAction SilentlyContinue
        if ($magickPath) {
            & magick $SourcePath -resize "$($MaxDim)x$($MaxDim)>" -quality 85 $DestinationPath 2>$null
            
            if (Test-Path $DestinationPath) {
                Write-Host "  Resized (ImageMagick): $([System.IO.Path]::GetFileName($SourcePath))"
                return
            }
        }
        
        # Fallback: just copy the file
        Write-Host "  No resizing tools available, copying original..."
        Copy-Item $SourcePath $DestinationPath -Force
        Write-Host "  Copied: $([System.IO.Path]::GetFileName($SourcePath))"
        
    } catch {
        Write-Host "  Error processing $SourcePath : $_"
        # Last resort: copy
        try {
            Copy-Item $SourcePath $DestinationPath -Force
            Write-Host "  Copied (fallback): $([System.IO.Path]::GetFileName($SourcePath))"
        } catch {
            Write-Host "  Failed completely: $_"
        }
    }
}

$absPath = Resolve-Path $FolderPath -ErrorAction Stop
$folder = Split-Path -Leaf $absPath
$webSafeFolder = ConvertTo-WebSafeFilename $folder

# Create web location folder
$webFolder = Join-Path "images" $webSafeFolder
if (-not (Test-Path $webFolder)) {
    New-Item -ItemType Directory -Path $webFolder -Force | Out-Null
}

# Gather image files from folder
$imageFiles = @(Get-ChildItem $absPath -File | Where-Object { $_.Extension -match '\.(jpg|jpeg|png|webp|gif)$' } | Sort-Object Name)

Write-Host "Processing $($imageFiles.Count) images..."

# Helper: normalize existing image entries
function Normalize-Image {
    param($item, [int]$index = 0)
    if (-not $item) { return $null }
    if ($item -is [string]) {
        $file = $item
        return [PSCustomObject]@{
            file     = $file
            name     = ""
            keywords = @()
        }
    }

    $file = $item.file
    if (-not $file -and $item.PSObject.Properties['src']) { $file = $item.src }
    if (-not $file -and $item.PSObject.Properties['path']) { $file = $item.path }

    if (-not $file) { return $null }

    $resolvedName = if ($item.PSObject.Properties['name'] -and $item.name) { $item.name } else { "" }

    return [PSCustomObject]@{
        file     = $file
        name     = $resolvedName
        keywords = @($item.keywords) | Where-Object { $_ -is [string] -and $_.Trim() -ne '' }
    }
}

# Build map of existing images (file => image object) for merging keywords/names
$jsonPath = "images/images.json"
$json = $null
if (Test-Path $jsonPath) {
    $content = Get-Content $jsonPath -Raw
    if ($content.Trim()) {
        $json = $content | ConvertFrom-Json
    }
}
if (-not $json) { $json = [PSCustomObject]@{ events = @() } }
if (-not $json.events) { $json | Add-Member -NotePropertyName events -NotePropertyValue @() }

$existingIdx = -1
for ($i = 0; $i -lt $json.events.Count; $i++) {
    if ($json.events[$i].folder -eq $webSafeFolder) { $existingIdx = $i; break }
}

$existingImagesMap = @{}
if ($existingIdx -ge 0 -and $json.events[$existingIdx].images) {
    foreach ($img in $json.events[$existingIdx].images) {
        $norm = Normalize-Image $img
        if ($null -ne $norm -and $norm.file) {
            $existingImagesMap[$norm.file] = $norm
        }
    }
}

# Build new image objects, copy and resize files
$imageObjects = @()
$counter = 0
foreach ($file in $imageFiles) {
    $counter++
    $fileName = $file.Name
    $webSafeFileName = ConvertTo-WebSafeFilename $fileName
    $sourceFullPath = $file.FullName
    $destFullPath = Join-Path $webFolder $webSafeFileName
    
    # Copy and resize image
    Write-Host "[$counter/$($imageFiles.Count)] Processing $fileName -> $webSafeFileName"
    Resize-Image $sourceFullPath $destFullPath $MaxDimension
    
    $existing = $existingImagesMap[$webSafeFileName]

    $imageObjects += [PSCustomObject]@{
        file     = $webSafeFileName
        name     = if ($existing -and $existing.name) { $existing.name } else { "" }
        keywords = if ($existing -and $existing.keywords) { @($existing.keywords) } else { @() }
    }
}

if ($existingIdx -ge 0) {
    $json.events[$existingIdx].name = $EventName
    $json.events[$existingIdx].folder = $webSafeFolder
    $json.events[$existingIdx].images = $imageObjects
} else {
    $json.events += [PSCustomObject]@{
        name   = $EventName
        folder = $webSafeFolder
        images = $imageObjects
    }
}

$json | ConvertTo-Json -Depth 10 | Out-File $jsonPath -Encoding UTF8
Write-Host "`n[OK] Event '$EventName' added/updated with $($imageObjects.Count) images in '$webSafeFolder'"
Write-Host "Images copied to: $webFolder"

# PowerShell Script to Generate images.json
# This script scans the images folder and creates/updates images.json with all image files

# Configuration
$imagesFolder = "images"
$outputFile = Join-Path $imagesFolder "images.json"
$supportedExtensions = @('.jpg', '.jpeg', '.png', '.webp', '.gif', '.JPG', '.JPEG', '.PNG', '.WEBP', '.GIF')

# Create images folder if it doesn't exist
if (-not (Test-Path $imagesFolder)) {
    New-Item -ItemType Directory -Path $imagesFolder
    Write-Host "Created 'images' folder" -ForegroundColor Green
}

# Get all image files from the images folder
$imageFiles = Get-ChildItem -Path $imagesFolder -File | Where-Object {
    $supportedExtensions -contains $_.Extension
} | Sort-Object Name

# Check if any images were found
if ($imageFiles.Count -eq 0) {
    Write-Host "No image files found in the 'images' folder." -ForegroundColor Yellow
    Write-Host "Supported formats: $($supportedExtensions -join ', ')" -ForegroundColor Yellow
    exit
}

# Load existing JSON if it exists
$existingImages = @()
if (Test-Path $outputFile) {
    try {
        $existingJson = Get-Content -Path $outputFile -Raw | ConvertFrom-Json
        $existingImages = $existingJson.images | ForEach-Object { $_ }
        Write-Host "Loaded existing images.json with $($existingImages.Count) entries" -ForegroundColor Cyan
    } catch {
        Write-Host "Could not parse existing images.json, starting fresh" -ForegroundColor Yellow
    }
}

# Create a hashtable of existing images by filename for quick lookup
$existingMap = @{}
$existingImages | ForEach-Object {
    $existingMap[$_.file] = $_
}

# Build image objects - merge with existing metadata or create new entries
$imageObjects = $imageFiles | ForEach-Object {
    $filename = $_.Name
    
    if ($existingMap.ContainsKey($filename)) {
        # Use existing entry with its metadata
        $existingMap[$filename]
    } else {
        # Create new entry with defaults
        $nameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($filename)
        [PSCustomObject]@{
            file     = $filename
            name     = $nameWithoutExt
            keywords = @()
        }
    }
}

# Create JSON structure
$jsonObject = @{
    images = $imageObjects
} | ConvertTo-Json -Depth 10

# Write to file with UTF-8 encoding
$jsonObject | Out-File -FilePath $outputFile -Encoding UTF8

# Display results
Write-Host "`nSuccessfully created images.json!" -ForegroundColor Green
Write-Host "Location: $outputFile" -ForegroundColor Cyan
Write-Host "Total images found: $($imageFiles.Count)" -ForegroundColor Cyan
Write-Host "`nImages included:" -ForegroundColor Yellow

$imageFiles | ForEach-Object {
    Write-Host "  - $($_.Name)" -ForegroundColor White
}

Write-Host "`nYour gallery is ready to use!" -ForegroundColor Green

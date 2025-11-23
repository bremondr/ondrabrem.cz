# PowerShell Script to Rename Images with Leading Underscores
# This script removes leading underscores from filenames and updates images.json

# Configuration
$imagesFolder = "images"
$jsonFile = Join-Path $imagesFolder "images.json"

# Load existing JSON
try {
    $jsonContent = Get-Content -Path $jsonFile -Raw | ConvertFrom-Json
    Write-Host "Loaded images.json" -ForegroundColor Green
} catch {
    Write-Host "Error loading images.json: $_" -ForegroundColor Red
    exit
}

# Get all image files that start with underscore
$filesToRename = Get-ChildItem -Path $imagesFolder -File | Where-Object {
    $_.Name -match '^_' -and @('.jpg', '.jpeg', '.png', '.webp', '.gif') -contains $_.Extension.ToLower()
}

if ($filesToRename.Count -eq 0) {
    Write-Host "No files with leading underscore found." -ForegroundColor Yellow
    exit
}

Write-Host "`nRenaming $($filesToRename.Count) files..." -ForegroundColor Cyan

# Rename files and update JSON
foreach ($file in $filesToRename) {
    $oldName = $file.Name
    $newName = $oldName -replace '^_', ''
    $oldPath = Join-Path $imagesFolder $oldName
    
    # Rename file on disk
    Rename-Item -Path $oldPath -NewName $newName
    Write-Host "  Renamed: $oldName → $newName" -ForegroundColor White
    
    # Update JSON - find and update the entry
    $imageEntry = $jsonContent.images | Where-Object { $_.file -eq $oldName }
    if ($imageEntry) {
        $imageEntry.file = $newName
        # Update name if it also had underscore prefix
        $newNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($newName)
        $imageEntry.name = $newNameWithoutExt
        Write-Host "    Updated JSON entry" -ForegroundColor Gray
    }
}

# Write updated JSON back to file
$jsonContent | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonFile -Encoding UTF8

Write-Host "`nSuccessfully renamed $($filesToRename.Count) files and updated images.json!" -ForegroundColor Green

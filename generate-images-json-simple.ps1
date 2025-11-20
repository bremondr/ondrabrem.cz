# Quick Image List Generator (creates objects with file/name/keywords)
$files = Get-ChildItem -Path "images" -Include *.jpg,*.jpeg,*.png,*.webp,*.gif -Recurse | Sort-Object Name
$images = $files | ForEach-Object {
    $nameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    [PSCustomObject]@{
        file     = $_.Name
        name     = $nameWithoutExt
        keywords = @()
    }
}
@{ images = $images } | ConvertTo-Json -Depth 10 | Out-File "images/images.json" -Encoding UTF8
Write-Host "images.json created with $($images.Count) images" -ForegroundColor Green

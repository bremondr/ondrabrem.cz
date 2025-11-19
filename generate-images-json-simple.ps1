# Quick Image List Generator
$images = Get-ChildItem -Path "images" -Include *.jpg,*.jpeg,*.png,*.webp,*.gif -Recurse | Select-Object -ExpandProperty Name
@{ images = $images } | ConvertTo-Json | Out-File "images/images.json" -Encoding UTF8
Write-Host "images.json created with $($images.Count) images" -ForegroundColor Green

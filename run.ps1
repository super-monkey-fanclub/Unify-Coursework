# Start Django backend in the background
Write-Host "Starting Django backend..." -ForegroundColor Cyan
$django = Start-Process -FilePath "python" `
    -ArgumentList "manage.py", "runserver" `
    -WorkingDirectory "$PSScriptRoot\backend" `
    -PassThru -NoNewWindow

Write-Host "Django running on http://127.0.0.1:8000" -ForegroundColor Green

# Give Django a moment to start
Start-Sleep -Seconds 2

# Run Flutter app
Write-Host "Starting Flutter app..." -ForegroundColor Cyan
Set-Location "$PSScriptRoot\unify_frontend"
flutter run

# When Flutter exits, stop Django
Write-Host "Stopping Django..." -ForegroundColor Yellow
Stop-Process -Id $django.Id -ErrorAction SilentlyContinue

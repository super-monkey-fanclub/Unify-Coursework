$ErrorActionPreference = 'Stop'

$backendDir = Join-Path $PSScriptRoot 'backend'
$frontendDir = Join-Path $PSScriptRoot 'unify_frontend'
$dockerComposePath = Join-Path $PSScriptRoot 'docker-compose.yml'

# Check if Docker is available
Write-Host "Checking for Docker..." -ForegroundColor Cyan
$dockerCheck = docker --version
if (-not $dockerCheck) {
    throw "Docker is not installed or not in PATH. Please install Docker Desktop from https://www.docker.com/products/docker-desktop"
}
Write-Host $dockerCheck -ForegroundColor Green

# Check if docker-compose is available
Write-Host "Checking for Docker Compose..." -ForegroundColor Cyan
$composeCheck = docker compose version 2>$null
if (-not $composeCheck) {
    throw "Docker Compose is not available. Please install Docker Desktop with Compose included."
}
Write-Host $composeCheck -ForegroundColor Green

# Load environment file if it exists, otherwise create it
$envFile = Join-Path $PSScriptRoot '.env'
if (-not (Test-Path $envFile)) {
    Write-Host "Creating .env file with default values..." -ForegroundColor Yellow
    Copy-Item (Join-Path $PSScriptRoot '.env.example') $envFile
    Write-Host ".env file created. You can customize database settings in .env if needed." -ForegroundColor Yellow
}

$flutterDevice = $env:FLUTTER_DEVICE
if ([string]::IsNullOrWhiteSpace($flutterDevice)) { $flutterDevice = 'chrome' }

Write-Host "Starting PostgreSQL database with Docker Compose..." -ForegroundColor Cyan
Push-Location $PSScriptRoot
try {
    docker compose up -d
    
    # Wait for PostgreSQL to be ready
    Write-Host "Waiting for PostgreSQL to be ready..." -ForegroundColor Cyan
    $maxAttempts = 30
    $attempt = 0
    while ($attempt -lt $maxAttempts) {
        try {
            docker compose exec -T postgres pg_isready -U postgres 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "PostgreSQL is ready!" -ForegroundColor Green
                break
            }
        }
        catch {
            # Ignore errors while waiting
        }
        $attempt++
        if ($attempt -lt $maxAttempts) {
            Start-Sleep -Seconds 1
        }
    }
    
    if ($attempt -eq $maxAttempts) {
        throw "PostgreSQL failed to start within timeout period. Check Docker logs with: docker compose logs"
    }
}
finally {
    Pop-Location
}

Write-Host "Running Django migrations..." -ForegroundColor Cyan
Push-Location $backendDir
try {
    python manage.py migrate
}
finally {
    Pop-Location
}

# Start Django backend in the background
Write-Host "Starting Django backend..." -ForegroundColor Cyan
$django = Start-Process -FilePath "python" `
    -ArgumentList "manage.py", "runserver", "127.0.0.1:8000" `
    -WorkingDirectory $backendDir `
    -PassThru -NoNewWindow

Write-Host "Django running on http://127.0.0.1:8000" -ForegroundColor Green
Write-Host "Admin panel available at http://127.0.0.1:8000/admin (no login required)" -ForegroundColor Green

# Give Django a moment to start
Start-Sleep -Seconds 2

try {
    # Run Flutter app
    Write-Host "Starting Flutter app..." -ForegroundColor Cyan
    Set-Location $frontendDir
    flutter run -d $flutterDevice --debug
}
finally {
    # When Flutter exits, stop Django
    Write-Host "Stopping Django..." -ForegroundColor Yellow
    if ($null -ne $django -and -not $django.HasExited) {
        Stop-Process -Id $django.Id -ErrorAction SilentlyContinue
    }
    
    # Stop Docker Compose
    Write-Host "Stopping PostgreSQL database..." -ForegroundColor Yellow
    Push-Location $PSScriptRoot
    try {
        docker compose down
    }
    finally {
        Pop-Location
    }
    Write-Host "Cleanup complete." -ForegroundColor Green
}
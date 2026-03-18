$ErrorActionPreference = 'Stop'

$backendDir = Join-Path $PSScriptRoot 'backend'
$frontendDir = Join-Path $PSScriptRoot 'unify_frontend'
$dockerComposePath = Join-Path $PSScriptRoot 'docker-compose.yml'

function Wait-ForPostgresPort {
    param(
        [Parameter(Mandatory = $true)][string]$Host,
        [Parameter(Mandatory = $true)][int]$Port,
        [int]$Attempts = 30,
        [int]$DelaySeconds = 1
    )

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        $client = $null
        try {
            $client = [System.Net.Sockets.TcpClient]::new()
            $async = $client.BeginConnect($Host, $Port, $null, $null)
            $connected = $async.AsyncWaitHandle.WaitOne(1000)
            if ($connected -and $client.Connected) {
                $client.EndConnect($async)
                return $true
            }
        }
        catch {
            # Keep retrying
        }
        finally {
            if ($null -ne $client) { $client.Close() }
        }

        if ($attempt -lt $Attempts) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    return $false
}

# Load environment file if it exists, otherwise create it
$envFile = Join-Path $PSScriptRoot '.env'
if (-not (Test-Path $envFile)) {
    Write-Host "Creating .env file with default values..." -ForegroundColor Yellow
    Copy-Item (Join-Path $PSScriptRoot '.env.example') $envFile
    Write-Host ".env file created. You can customize database settings in .env if needed." -ForegroundColor Yellow
}

$flutterDevice = $env:FLUTTER_DEVICE
if ([string]::IsNullOrWhiteSpace($flutterDevice)) { $flutterDevice = 'chrome' }

$dbHost = $env:DB_HOST
if ([string]::IsNullOrWhiteSpace($dbHost)) { $dbHost = 'localhost' }

$dbPort = $env:DB_PORT
if ([string]::IsNullOrWhiteSpace($dbPort)) { $dbPort = '5432' }

[int]$dbPortNumber = 5432
try {
    $dbPortNumber = [int]$dbPort
}
catch {
    throw "Invalid DB_PORT '$dbPort'. Please set DB_PORT to a valid integer value in .env."
}

$dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
$useDocker = $false
$dockerStarted = $false

if ($null -ne $dockerCommand -and (Test-Path $dockerComposePath)) {
    Write-Host "Docker detected. Using Docker Compose for PostgreSQL..." -ForegroundColor Cyan
    $composeCheck = (& docker compose version 2>$null)
    if ($LASTEXITCODE -eq 0) {
        $useDocker = $true
        if ($composeCheck) { Write-Host $composeCheck -ForegroundColor Green }
    }
    else {
        Write-Host "Docker found but 'docker compose' is unavailable. Falling back to local PostgreSQL." -ForegroundColor Yellow
    }
}
else {
    Write-Host "Docker not found. Falling back to local PostgreSQL." -ForegroundColor Yellow
}

if ($useDocker) {
    Write-Host "Starting PostgreSQL database with Docker Compose..." -ForegroundColor Cyan
    Push-Location $PSScriptRoot
    try {
        docker compose up -d
        $dockerStarted = $true

        Write-Host "Waiting for PostgreSQL to be ready..." -ForegroundColor Cyan
        $ready = Wait-ForPostgresPort -Host $dbHost -Port $dbPortNumber -Attempts 45 -DelaySeconds 1
        if (-not $ready) {
            throw "PostgreSQL failed to start within timeout period. Check Docker logs with: docker compose logs"
        }

        Write-Host "PostgreSQL is ready." -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Host "Checking local PostgreSQL on $dbHost:$dbPortNumber..." -ForegroundColor Cyan
    $ready = Wait-ForPostgresPort -Host $dbHost -Port $dbPortNumber -Attempts 3 -DelaySeconds 1
    if (-not $ready) {
        $postgresServices = @(Get-Service | Where-Object { $_.Name -match 'postgresql' -or $_.DisplayName -match 'PostgreSQL' })

        if ($postgresServices.Count -gt 0) {
            Write-Host "Local PostgreSQL service found. Attempting to start..." -ForegroundColor Cyan
            foreach ($service in $postgresServices) {
                if ($service.Status -ne 'Running') {
                    try {
                        Start-Service -Name $service.Name -ErrorAction Stop
                        Write-Host "Started service $($service.Name)." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Could not start service $($service.Name): $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                }
            }
        }

        $ready = Wait-ForPostgresPort -Host $dbHost -Port $dbPortNumber -Attempts 20 -DelaySeconds 1
        if (-not $ready) {
            throw "Could not connect to PostgreSQL at $dbHost:$dbPortNumber. Install Docker Desktop and rerun '.\\run.ps1', or start your local PostgreSQL service and verify DB_HOST/DB_PORT in .env."
        }
    }

    Write-Host "Local PostgreSQL is reachable." -ForegroundColor Green
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
    
    if ($useDocker -and $dockerStarted) {
        Write-Host "Stopping PostgreSQL database (Docker Compose)..." -ForegroundColor Yellow
        Push-Location $PSScriptRoot
        try {
            docker compose down
        }
        finally {
            Pop-Location
        }
    }
    else {
        Write-Host "Leaving local PostgreSQL running." -ForegroundColor Yellow
    }

    Write-Host "Cleanup complete." -ForegroundColor Green
}
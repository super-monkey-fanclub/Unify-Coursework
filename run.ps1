$ErrorActionPreference = 'Stop'

function Get-PostgresToolPath {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('psql', 'createdb')][string]$Tool
    )

    $fromPath = (Get-Command $Tool -ErrorAction SilentlyContinue).Source
    if (-not [string]::IsNullOrWhiteSpace($fromPath)) {
        return $fromPath
    }

    $candidates = @(
        Get-ChildItem -Path 'C:\Program Files\PostgreSQL' -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        ForEach-Object { Join-Path $_.FullName "bin\$Tool.exe" }
    )

    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    return $null
}

$backendDir = Join-Path $PSScriptRoot 'backend'
$frontendDir = Join-Path $PSScriptRoot 'unify_frontend'
$schemaFile = Join-Path $PSScriptRoot 'Database\unify.sql'

$flutterDevice = $env:FLUTTER_DEVICE
if ([string]::IsNullOrWhiteSpace($flutterDevice)) { $flutterDevice = 'chrome' }

$dbName = $env:DB_NAME
if ([string]::IsNullOrWhiteSpace($dbName)) { $dbName = 'unify' }

$dbUser = $env:DB_USER
if ([string]::IsNullOrWhiteSpace($dbUser)) { $dbUser = 'postgres' }

$dbPassword = $env:DB_PASSWORD
if ([string]::IsNullOrWhiteSpace($dbPassword)) { $dbPassword = 'postgres' }

$dbHost = $env:DB_HOST
if ([string]::IsNullOrWhiteSpace($dbHost)) { $dbHost = 'localhost' }

$dbPort = $env:DB_PORT
if ([string]::IsNullOrWhiteSpace($dbPort)) { $dbPort = '5432' }

$psql = Get-PostgresToolPath -Tool 'psql'
$createdb = Get-PostgresToolPath -Tool 'createdb'

if (-not $psql -or -not $createdb) {
    throw "PostgreSQL tools not found. Install PostgreSQL, or add psql/createdb to PATH (expected under C:\\Program Files\\PostgreSQL\\<version>\\bin)."
}

if (-not (Test-Path $schemaFile)) {
    throw "Schema file not found: $schemaFile"
}

Write-Host "Ensuring PostgreSQL database '$dbName' exists..." -ForegroundColor Cyan
$env:PGPASSWORD = $dbPassword

Write-Host "Checking PostgreSQL connection on ${dbHost}:$dbPort..." -ForegroundColor Cyan
& $psql -h $dbHost -p $dbPort -U $dbUser -d postgres -c "SELECT 1;" -t -A 1>$null
if ($LASTEXITCODE -ne 0) {
    throw "Could not connect to PostgreSQL at ${dbHost}:$dbPort as user '$dbUser'. Ensure the PostgreSQL service is running and DB_HOST/DB_PORT/DB_USER/DB_PASSWORD are correct."
}

try {
    $dbExists = & $psql -h $dbHost -p $dbPort -U $dbUser -d postgres -t -A -c "SELECT 1 FROM pg_database WHERE datname = '$dbName';"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to check whether database '$dbName' exists."
    }

    if ("$dbExists".Trim() -ne '1') {
        & $createdb -h $dbHost -p $dbPort -U $dbUser $dbName
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create database '$dbName'. Check PostgreSQL permissions for user '$dbUser'."
        }
    }
}
catch {
    throw
}

Write-Host "Running Django migrations..." -ForegroundColor Cyan
Push-Location $backendDir
try {
    python manage.py migrate
}
finally {
    Pop-Location
}

Write-Host "Loading schema into '$dbName' from unify.sql..." -ForegroundColor Cyan
& $psql -h $dbHost -p $dbPort -U $dbUser -d $dbName -f $schemaFile

# Start Django backend in the background
Write-Host "Starting Django backend..." -ForegroundColor Cyan
$django = Start-Process -FilePath "python" `
    -ArgumentList "manage.py", "runserver", "127.0.0.1:8000" `
    -WorkingDirectory $backendDir `
    -PassThru -NoNewWindow

Write-Host "Django running on http://127.0.0.1:8000" -ForegroundColor Green

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
}
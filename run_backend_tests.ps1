Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Set-Location -LiteralPath (Join-Path $PSScriptRoot 'backend')
python manage.py test core.test_user_requirements core.test_admin_requirements core.test_system_requirements -v 2

if ($LASTEXITCODE -eq 0) {
    Write-Host 'All tests passed!'
    exit 0
}

exit $LASTEXITCODE
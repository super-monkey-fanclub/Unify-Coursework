Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Set-Location -LiteralPath (Join-Path $PSScriptRoot 'unify_frontend')
flutter test test/frontend_requirements_test.dart test/widget_test.dart test/home_test.dart test/auth_navigation_test.dart test/societies_navigation_and_search_test.dart test/society_review_test.dart

if ($LASTEXITCODE -eq 0) {
    Write-Host 'All tests passed!'
    exit 0
}

exit $LASTEXITCODE
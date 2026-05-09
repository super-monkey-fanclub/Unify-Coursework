# Unify Test Report

**Project:** Unify - Society Management Platform  
**Scope:** Backend and frontend automated tests  
**Status:** PASS  

## How to run the tests

Run the backend tests from the repo root with the wrapper script:

.
.\run_backend_tests.ps1

Run the frontend tests from the repo root with the wrapper script:

.
.\run_frontend_tests.ps1

## Passing terminal results

### Backend

The backend requirement tests passed and the wrapper printed the success line:

- `Ran 39 tests in 52.419s`
- `OK`
- `All tests passed!`

### Frontend

The frontend widget tests passed and the wrapper printed the success line:

- `All tests passed!`

## Test files included in this report

### Backend test files

- [backend/core/test_user_requirements.py](backend/core/test_user_requirements.py)
- [backend/core/test_admin_requirements.py](backend/core/test_admin_requirements.py)
- [backend/core/test_system_requirements.py](backend/core/test_system_requirements.py)

### Frontend test files

- [unify_frontend/test/frontend_requirements_test.dart](unify_frontend/test/frontend_requirements_test.dart)
- [unify_frontend/test/widget_test.dart](unify_frontend/test/widget_test.dart)
- [unify_frontend/test/home_test.dart](unify_frontend/test/home_test.dart)
- [unify_frontend/test/auth_navigation_test.dart](unify_frontend/test/auth_navigation_test.dart)
- [unify_frontend/test/societies_navigation_and_search_test.dart](unify_frontend/test/societies_navigation_and_search_test.dart)
- [unify_frontend/test/society_review_test.dart](unify_frontend/test/society_review_test.dart)

## Coverage summary

### Backend coverage

These tests cover the backend requirements around:

- User registration and login
- Joining societies and membership checks
- Review creation rules, including the 2-week waiting period
- Offensive language rejection for reviews
- Review likes, dislikes, and admin restrictions
- Anonymous poll voting and single-vote enforcement
- Poll creation rules for admins
- Poll duration limits
- Poll option count limits
- Duplicate poll prevention
- Review deletion and admin responses
- Review analytics and notification creation
- Account settings updates
- Poll deletion timing restrictions
- Society metrics such as member count and average rating

### Frontend coverage

These tests cover the Flutter UI and navigation flows around:

- Home page rendering and navigation actions
- About page content
- Auth page opening and validation
- Account settings page rendering
- Society details page rendering
- Search results filtering
- Society review and navigation flows
- Compact-screen rendering for the home page

## Result

All targeted backend and frontend automated tests passed in the terminal, and both wrapper commands end with `All tests passed!` when the suite succeeds.

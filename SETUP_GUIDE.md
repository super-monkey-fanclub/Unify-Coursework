# Development Setup Guide - Admin & Database Access

## Overview

This project prefers **Docker Compose** to manage PostgreSQL across all developer machines, and can also fall back to a local PostgreSQL service if Docker is not installed. The admin panel is accessible without authentication for development purposes.

## Prerequisites

1. **PostgreSQL runtime (choose one)**
   - **Recommended**: Docker Desktop - [Download here](https://www.docker.com/products/docker-desktop)
     - Includes Docker Engine and Docker Compose
     - Provides consistent database setup for the whole team
   - **Alternative**: Local PostgreSQL service running on your machine
   
2. **Python 3.9+** - For running Django backend

3. **Flutter SDK** - For running the mobile/web app frontend

## Quick Start

### 1. Install Dependencies

From the project root directory:

```powershell
pip install -r requirements.txt
```

### 2. Setup Environment Variables (Optional)

A `.env` file will be created automatically when you first run the app. If you need to customize database settings:

```powershell
Copy-Item .env.example .env
```

Default values work for most use cases:
- **DB_NAME**: `unify`
- **DB_USER**: `postgres`
- **DB_PASSWORD**: `postgres`
- **DB_HOST**: `localhost`
- **DB_PORT**: `5432`

### 3. Launch Everything

```powershell
.\run.ps1
```

This script will:
- ✅ Start PostgreSQL in Docker (if available), otherwise use/start local PostgreSQL
- ✅ Wait for the database to be ready
- ✅ Run Django migrations
- ✅ Start Django development server (http://127.0.0.1:8000)
- ✅ Launch Flutter app
- ✅ Clean up when you exit (always stops backend; stops DB only if started via Docker)

## Accessing Admin Panel

**URL**: http://127.0.0.1:8000/admin/

**Features**:
- No login required in development
- All users automatically get admin privileges
- Default admin user (`admin`/`admin`) is created automatically
- Full access to database management through Django admin interface

## Database Management

### View Database Logs

```powershell
docker compose logs postgres
```

### Access Database via psql

```powershell
docker compose exec postgres psql -U postgres -d unify
```

### Reset Database

```powershell
docker compose down -v  # Remove volumes to reset data
.\run.ps1               # Recreate fresh database
```

### Manual Backup/Restore

**Backup**:
```powershell
docker compose exec postgres pg_dump -U postgres unify > backup.sql
```

**Restore**:
```powershell
docker compose exec postgres psql -U postgres unify < backup.sql
```

## Environment Variables

You can override database settings by setting environment variables before running the script:

```powershell
$env:DB_NAME = "my_unify_db"
$env:DB_USER = "custom_user"
$env:DB_PASSWORD = "strong_password"
.\run.ps1
```

Or add them to your `.env` file.

## Troubleshooting

### Docker not found

If Docker is not installed, `run.ps1` automatically falls back to local PostgreSQL.

If startup still fails, ensure local PostgreSQL is running and your `.env` values are correct:

```powershell
DB_HOST=localhost
DB_PORT=5432
```

You can still install Docker later for a more consistent team setup: [Install Docker Desktop](https://www.docker.com/products/docker-desktop)

### Port already in use

If port 5432 is already in use:

```powershell
# Stop the conflicting container
docker ps
docker stop <container_id>

# Or use a different port in .env
$env:DB_PORT = "5433"
```

### Database connection failed

```powershell
# Check if containers are running
docker compose ps

# View logs
docker compose logs

# Restart
docker compose restart
```

### Clear everything and start fresh

```powershell
docker compose down -v
rm .env  # Optional: force recreation with defaults
.\run.ps1
```

## Architecture

```
┌─────────────────────────────────────────┐
│          Flutter Frontend               │
│      (Chrome/iOS/Android/etc)           │
└──────────────┬──────────────────────────┘
               │ HTTP Requests
               ↓
┌─────────────────────────────────────────┐
│       Django Backend (8000)             │
│  • Admin Panel (auto-login)             │
│  • REST API endpoints                   │
│  • CORS enabled for local dev           │
└──────────────┬──────────────────────────┘
               │ Database Queries
               ↓
┌─────────────────────────────────────────┐
│  PostgreSQL (Docker - Port 5432)        │
│  • Database: unify                      │
│  • User: postgres                       │
│  • Auto-starts with docker compose up   │
└─────────────────────────────────────────┘
```

## Important Security Notes

⚠️ **Development Only**: The unauthenticated admin access is **ONLY for development**. Never use this configuration in production.

For production deployment:
1. Remove the `DevAdminAuthMiddleware` from middleware
2. Implement proper authentication (JWT, OAuth2, etc.)
3. Use environment-specific Django settings
4. Store secrets in environment variables/vaults
5. Disable `DEBUG = True`

## Admin Features Available

Once logged in to the admin panel, you can:

- **Manage Users** - Create users, assign permissions
- **Manage Content** - Add/edit/delete polls, societies, etc.
- **View Logs** - Check system activity
- **Database Management** - Full access through Django ORM interface
- **REST Framework** - Modify API endpoints

## Support

For issues or questions, check Docker logs:

```powershell
docker compose logs -f  # View real-time logs
```

Or Django logs in the console where you ran `.\run.ps1`

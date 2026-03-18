# Quick Reference - Getting Started

## One-Command Start

```powershell
.\run.ps1
```

That's it! This will:
- Start PostgreSQL database (Docker)
- Run migrations
- Start Django backend
- Start Flutter app

## Access Points

| Service | URL | Notes |
|---------|-----|-------|
| **Admin Panel** | http://127.0.0.1:8000/admin | No login required, auto-authenticated |
| **Django Server** | http://127.0.0.1:8000 | Development server |
| **Flutter App** | Automatically opens in browser/device | |

## First Time Setup

1. **Ensure Docker Desktop is installed**
   - Download from https://www.docker.com/products/docker-desktop

2. **Install Python packages**
   ```powershell
   pip install -r requirements.txt
   ```

3. **Run**
   ```powershell
   .\run.ps1
   ```

4. **Open admin**
   - http://127.0.0.1:8000/admin/
   - No password needed!

## Important Files

- `docker-compose.yml` - Database container config
- `.env` - Database credentials (created automatically)
- `backend/middleware.py` - Admin auto-login logic
- `backend/settings.py` - Django configuration
- `run.ps1` - Launch script
- `SETUP_GUIDE.md` - Detailed setup instructions
- `IMPLEMENTATION_DETAILS.md` - Technical documentation

## Admin Panel Features

Once you open http://127.0.0.1:8000/admin/:

- **View/Edit Users** - Create test accounts
- **Manage Data** - Add societies, polls, etc.
- **Manage Permissions** - Control what users can do
- **View Logs** - See system activity

## Common Issues

**"Docker not found"**
- Install Docker Desktop: https://www.docker.com/products/docker-desktop
- Restart your terminal after installation

**"Port 5432 already in use"**
- Either stop the conflicting app
- Or change port in `.env`: `DB_PORT=5433`

**"Can't connect to database"**
- Wait 30 seconds for database to start
- Check: `docker compose ps`
- View logs: `docker compose logs postgres`

**"Go to admin but get login page"**
- This shouldn't happen! Middleware should auto-login
- Try: Clear browser cache, refresh, or use incognito mode
- Restart: Close browser, run `.\run.ps1` again

## Stop Everything

Just close the terminal or press `Ctrl+C`

When you exit, the script automatically:
- Stops Django
- Stops the database
- Cleans up ports

## Environment Variables (Optional)

Edit `.env` file to change database settings:

```
DB_NAME=unify              # Database name
DB_USER=postgres           # Database user
DB_PASSWORD=postgres       # Database password
DB_HOST=localhost          # Database host
DB_PORT=5432              # Database port
FLUTTER_DEVICE=chrome     # Device to run Flutter on
```

No need to change these unless you have conflicts.

## For Mac/Linux Users

The script uses PowerShell, which works on all platforms (Windows 10+, macOS, Linux):

```bash
pwsh ./run.ps1
```

Or just run it manually:
```bash
# Start database
docker compose up -d

# Run migrations
cd backend && python manage.py migrate && cd ..

# Start Django (terminal 1)
cd backend && python manage.py runserver

# Start Flutter (terminal 2)
cd unify_frontend && flutter run -d chrome
```

## Database Backups

**Save current database**:
```powershell
docker compose exec postgres pg_dump -U postgres unify > backup.sql
```

**Restore from backup**:
```powershell
docker compose exec postgres psql -U postgres unify < backup.sql
```

## Developer Credentials

- **Admin Username**: `admin`
- **Admin Password**: Not needed (auto-login)
- **Database User**: `postgres`
- **Database Password**: `postgres` (or whatever you set in `.env`)

## Team Workflow

1. Each developer runs `.\run.ps1`
2. Gets identical database setup via Docker
3. Opens admin panel - full access, no login
4. Can manage data without coordination
5. Changes are visible to everyone (same database)

## Performance Tips

- If app is slow on first start, wait 30 seconds for database
- Use `flutter run` with `-d chrome` for web development
- Use `-d windows`/`-d macos`/`-d linux` for desktop development
- Use `-d <device-id>` for physical device/emulator

## See Also

- `SETUP_GUIDE.md` - Detailed setup and troubleshooting
- `IMPLEMENTATION_DETAILS.md` - Technical architecture
- `docker-compose.yml` - Database configuration

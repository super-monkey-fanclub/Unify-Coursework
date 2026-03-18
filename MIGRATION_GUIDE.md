# Migration Guide: What's Changed

## For Existing Team Members

If you've been working with the old setup, here's what changed and what you need to do.

## What Changed

### Before
- Required PostgreSQL installed locally on each machine
- Each developer needed to manage their own database
- Different configurations across team machines
- Environment variables had to be set manually

### After
- PostgreSQL runs in Docker (same for everyone)
- Database auto-starts with the app
- `.env` file handles configuration
- One command to run everything: `.\run.ps1`

## Breaking Changes

None! Your existing data and setup still work. But the new approach is easier.

## Migration Steps

### 1. Update Your Code
```powershell
git pull origin main
```

### 2. Install New Dependencies
```powershell
pip install -r requirements.txt
```

The only new requirement is `python-dotenv` (already listed).

### 3. Install Docker
If you don't have Docker Desktop:
- **Windows**: https://www.docker.com/products/docker-desktop
- **Mac**: https://www.docker.com/products/docker-desktop
- **Linux**: https://docs.docker.com/engine/install/

### 4. Create `.env` File
The script does this automatically, but you can do it manually:
```powershell
Copy-Item .env.example .env
```

### 5. Stop Old PostgreSQL (if running)
```powershell
# Windows - if you had PostgreSQL running
Get-Service "PostgreSQL*" | Stop-Service
```

### 6. Run the New Script
```powershell
.\run.ps1
```

## What's Different Now

### Database

**Old Way**:
```powershell
# You had to do this
Set-Location backend
python manage.py migrate
cd ..
```

**New Way**:
```powershell
# The script does this automatically
.\run.ps1
```

### Admin Panel

**Old Way**:
```
Username: admin
Password: <whatever you set it to>
```

**New Way**:
```
No login required!
Just open: http://127.0.0.1:8000/admin/
```

### Database Credentials

**Old Way**: Set in Django settings or environment
```powershell
# or manually configured in settings.py
```

**New Way**: `.env` file
```
DB_NAME=unify
DB_USER=postgres
DB_PASSWORD=postgres
```

## If You Had Local PostgreSQL

You can keep it or switch to Docker. To keep your local one:

1. Don't run `.\run.ps1` (it starts Docker version)
2. Start your PostgreSQL service manually
3. Update `.env`:
   ```
   DB_HOST=localhost
   DB_PORT=5432
   DB_USER=<your user>
   DB_PASSWORD=<your password>
   ```
4. Run Django and Flutter manually:
   ```powershell
   cd backend
   python manage.py runserver
   
   # In another terminal
   cd unify_frontend
   flutter run -d chrome
   ```

But we recommend using Docker - it's easier!

## Backing Up Old Database

Before switching, export your current database:

```powershell
# If using old local PostgreSQL
pg_dump -U postgres unify > my_backup.sql

# Keep this safe!
```

Then when using Docker version:

```powershell
docker compose exec postgres psql -U postgres unify < my_backup.sql
```

## FAQ

**Q: Can I still use my local PostgreSQL?**
A: Yes, but you'll need to start it manually and not use `.\run.ps1`

**Q: Will my existing database work?**
A: Yes! You can import it using `docker compose exec postgres psql`

**Q: Do I need Docker if I already have PostgreSQL?**
A: Not required, but recommended for consistency across the team

**Q: Can I use different database credentials?**
A: Yes, edit the `.env` file

**Q: What if Docker takes up too much disk space?**
A: Run `docker image prune` to clean up unused images

**Q: Can I reset the database?**
A: Yes! `docker compose down -v` then `.\run.ps1`

**Q: Does this work with my IDE debugger?**
A: Yes! The script runs Django in a normal process, not in Docker

## Rollback (if needed)

If you want to go back to the old setup:

1. Don't run `.\run.ps1`
2. Start your old PostgreSQL service
3. Run Django and Flutter manually
4. Remove `.env` file (optional)

But contact the team first - we want everyone on the same approach!

## Troubleshooting Migration

**"Error: Database 'unify' does not exist"**
- Docker version is starting fresh
- Option 1: Run migrations (automatic with `.\run.ps1`)
- Option 2: Import your old backup:
  ```powershell
  docker compose exec postgres psql -U postgres < your_backup.sql
  ```

**"Permission denied trying to connect"**
- Check `.env` database credentials
- Verify PostgreSQL in Docker is running: `docker compose ps`

**"Can't get to admin"**
- Wait 30 seconds for database startup
- Open: http://127.0.0.1:8000/admin/
- No login needed!

**"Flutter can't connect to backend"**
- Backend should be at http://127.0.0.1:8000
- Check: `docker compose ps` and Django server is running

## Need Help?

1. Check `SETUP_GUIDE.md` for detailed instructions
2. Check `IMPLEMENTATION_DETAILS.md` for technical info
3. Check `QUICKSTART.md` for quick reference
4. Run `docker compose logs` to see database logs
5. Check Terminal output for Django errors

## Team Sync

Once everyone migrates:
- Everyone gets identical database setup
- Easier onboarding for new developers
- Consistent development environment
- Less troubleshooting

This is a good thing! ✅

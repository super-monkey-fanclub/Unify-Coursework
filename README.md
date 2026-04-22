# Unify-Coursework
Joshua Alcazar - up2267668 235305961
Maria - up2305949 235307556
Adefola - up2274013 237086770
Beau - up2281726 237248106
Maya - up2266552  198966765
Michael - up2273239 183396154

## Backend Quick Start

### 1) Install dependencies

```powershell
python -m pip install -r requirements.txt
```

### 2) Apply migrations

```powershell
python backend/manage.py migrate
```

## Quick Continuous Run (Development)

Use two terminals so both the API and scheduled jobs keep running.

### Terminal A: Run API server

```powershell
python backend/manage.py runserver
```

### Terminal B: Run scheduler

```powershell
python backend/manage.py run_scheduler
```

Optional: change poll notification check interval from default 5 minutes.

```powershell
$env:POLL_NOTIFICATIONS_INTERVAL_MINUTES = "10"
python backend/manage.py run_scheduler
```

Notes:
- If Terminal B is closed, scheduled poll/monthly notifications stop.
- Keep both terminals open during local development.

# Socialize Project Deployment

Deployment for Socialize backend (Rails API) and frontend (React) using Kamal 2.

## Usage

- Configure secrets in `.kamal/secrets-common` (copy from `.kamal/secrets-common.example`).  
- Use the deploy script for everything:

```bash
./deploy.sh setup            # First-time backend
./deploy.sh setup-frontend   # First-time frontend
./deploy.sh deploy           # Backend only
./deploy.sh deploy-frontend  # Frontend only
./deploy.sh deploy-all       # Both services
./deploy.sh status           # Check status
```

See deploy.sh for more commands, like running migrations, database reset, logs, etc.

## Access
- Backend API: https://socializeproject.com/api/v1<br>
    Currently using v1; future versions (v2, v3, etc.) may be added as the API evolves
- Frontend: https://socializeproject.com

## Notes
Do not commit .kamal/secrets-common.

Frontend and backend are submodules; no need to track them manually.
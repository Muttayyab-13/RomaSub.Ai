# RomaSub.AI - Docker Setup Guide

This guide explains how to run RomaSub.AI using Docker containers. Docker makes it easy to run the application on any machine without worrying about dependencies.

---

## Prerequisites

Before you begin, make sure you have installed:

1. **Docker Desktop** (for Windows/Mac) or **Docker Engine** (for Linux)
   - Download from: https://www.docker.com/products/docker-desktop
   - Minimum version: Docker 20.10+, Docker Compose 2.0+

2. **Git** (to clone the repository)
   - Download from: https://git-scm.com/downloads

---

## Quick Start (For Your Colleague)

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd RomaSub.Ai
```

### Step 2: Create Environment File (Optional)

Create a `.env` file in the project root for custom configuration:

```bash
# Copy the example file
cp .env.example .env

# Edit .env with your preferred text editor
# Minimal required configuration:
SECRET_KEY=your-random-secret-key-here

# Optional configurations:
# GOOGLE_CLIENT_ID=your-google-client-id
# GOOGLE_CLIENT_SECRET=your-google-client-secret
# MAILERSEND_API_KEY=your-mailersend-api-key
# WHISPER_MODEL=small
```

**Note:** If you don't create a `.env` file, Docker Compose will use default values.

### Step 3: Start the Application

```bash
# Build and start all containers
docker-compose up -d

# Or, if using newer Docker Compose CLI:
docker compose up -d
```

This command will:
- Download the PostgreSQL image
- Build the RomaSub.AI backend image
- Create and start both containers
- Set up networking between them
- Initialize the database

### Step 4: Verify Everything is Running

```bash
# Check container status
docker-compose ps

# You should see:
# - romasub_db (running)
# - romasub_backend (running)
```

### Step 5: Access the Application

- **API Documentation (Swagger UI):** http://localhost:8000/docs
- **Alternative API Docs (ReDoc):** http://localhost:8000/redoc
- **Health Check:** http://localhost:8000/health
- **Root Endpoint:** http://localhost:8000/

---

## Docker Commands Reference

### Starting the Application

```bash
# Start in background (detached mode)
docker-compose up -d

# Start with logs visible
docker-compose up

# Rebuild and start (after code changes)
docker-compose up -d --build
```

### Stopping the Application

```bash
# Stop all containers
docker-compose stop

# Stop and remove containers (data is preserved in volumes)
docker-compose down

# Stop and remove everything including volumes (⚠️ deletes database data)
docker-compose down -v
```

### Viewing Logs

```bash
# View logs from all containers
docker-compose logs

# View logs from backend only
docker-compose logs backend

# View logs from database only
docker-compose logs db

# Follow logs in real-time
docker-compose logs -f

# View last 100 lines
docker-compose logs --tail=100
```

### Database Management

```bash
# Access PostgreSQL shell
docker-compose exec db psql -U postgres -d romasub_ai

# Backup database
docker-compose exec db pg_dump -U postgres romasub_ai > backup.sql

# Restore database
docker-compose exec -T db psql -U postgres romasub_ai < backup.sql

# Reset database (⚠️ deletes all data)
docker-compose down -v
docker-compose up -d
```

### Container Management

```bash
# Restart a specific container
docker-compose restart backend

# View container resource usage
docker stats

# Execute command inside backend container
docker-compose exec backend bash

# Execute command inside database container
docker-compose exec db bash
```

---

## Architecture

The Docker setup consists of two main services:

### 1. PostgreSQL Database (`db`)
- **Image:** `postgres:15-alpine`
- **Port:** 5432 (exposed to host)
- **Volume:** `postgres_data` (persists database data)
- **Environment:**
  - Database: `romasub_ai`
  - User: `postgres`
  - Password: `romasub_password`

### 2. FastAPI Backend (`backend`)
- **Build:** Custom Dockerfile
- **Port:** 8000 (exposed to host)
- **Volumes:**
  - `upload_data`: Temporary file uploads
  - `static_data`: Static files (profile pictures, etc.)
- **Dependencies:** Waits for database to be healthy before starting

---

## Configuration

### Environment Variables

You can configure the application using environment variables in `.env` file or by editing `docker-compose.yml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `SECRET_KEY` | (generated) | JWT secret key for authentication |
| `DATABASE_URL` | (auto-configured) | PostgreSQL connection string |
| `WHISPER_MODEL` | `small` | Whisper ASR model (tiny/base/small/medium/large) |
| `MAX_FILE_SIZE_MB` | `500` | Maximum upload file size in MB |
| `GOOGLE_CLIENT_ID` | (optional) | Google OAuth client ID |
| `GOOGLE_CLIENT_SECRET` | (optional) | Google OAuth client secret |
| `MAILERSEND_API_KEY` | (optional) | MailerSend API key for emails |

### Changing Database Password

Edit `docker-compose.yml`:

```yaml
services:
  db:
    environment:
      POSTGRES_PASSWORD: your_new_password

  backend:
    environment:
      DATABASE_URL: postgresql://postgres:your_new_password@db:5432/romasub_ai
```

### Using Different Whisper Model

For better accuracy (but slower), use a larger model:

```yaml
backend:
  environment:
    WHISPER_MODEL: medium  # or large
```

---

## Troubleshooting

### Port Already in Use

If port 8000 or 5432 is already in use, change it in `docker-compose.yml`:

```yaml
backend:
  ports:
    - "8001:8000"  # Use port 8001 on host

db:
  ports:
    - "5433:5432"  # Use port 5433 on host
```

### Database Connection Errors

```bash
# Check if database is running
docker-compose ps db

# View database logs
docker-compose logs db

# Restart database
docker-compose restart db
```

### Backend Not Starting

```bash
# View backend logs
docker-compose logs backend

# Rebuild backend image
docker-compose build --no-cache backend
docker-compose up -d backend
```

### Out of Disk Space

```bash
# Remove unused Docker images and containers
docker system prune -a

# Remove all volumes (⚠️ deletes all data)
docker volume prune
```

### Container Keeps Restarting

```bash
# Check logs for errors
docker-compose logs -f backend

# Common issues:
# - Missing required environment variables
# - Database not accessible
# - Port conflicts
```

---

## Development with Docker

### Hot Reload (Code Changes)

To enable hot reload during development, mount your code as a volume in `docker-compose.yml`:

```yaml
backend:
  volumes:
    - ./app:/app/app  # Mount source code
    - upload_data:/tmp/romasub_uploads
    - static_data:/app/uploads
  command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### Installing New Python Packages

```bash
# Add package to requirements.txt
echo "new-package==1.0.0" >> requirements.txt

# Rebuild backend image
docker-compose build backend

# Restart backend
docker-compose up -d backend
```

### Running Database Migrations

```bash
# Access backend container
docker-compose exec backend bash

# Run Alembic migrations (when implemented)
alembic upgrade head
```

---

## Production Considerations

Before deploying to production:

1. **Change Default Passwords**
   - Generate a strong `SECRET_KEY`
   - Change PostgreSQL password

2. **Configure CORS**
   - Edit `app/main.py` to specify allowed origins
   - Don't use `allow_origins=["*"]` in production

3. **Use Environment Variables**
   - Store secrets in `.env` file (not in git)
   - Use Docker secrets or environment management tools

4. **Enable HTTPS**
   - Use a reverse proxy (Nginx, Traefik, Caddy)
   - Configure SSL certificates

5. **Resource Limits**
   - Add memory and CPU limits in `docker-compose.yml`:
   ```yaml
   backend:
     deploy:
       resources:
         limits:
           cpus: '2'
           memory: 4G
   ```

6. **Backup Strategy**
   - Set up automated database backups
   - Backup uploaded files regularly

7. **Monitoring**
   - Add logging aggregation
   - Set up health check monitoring
   - Use Docker healthchecks

---

## Sharing with Team Members

### Method 1: Git Repository (Recommended)

Your colleague just needs to:
```bash
git clone <repository-url>
cd RomaSub.Ai
docker-compose up -d
```

### Method 2: Docker Image Export/Import

If you want to share the built image without source code:

```bash
# On your machine - save image to file
docker save romasub-ai-backend:latest | gzip > romasub-backend.tar.gz

# Send romasub-backend.tar.gz to your colleague

# On colleague's machine - load image
docker load < romasub-backend.tar.gz

# Then run with docker-compose
docker-compose up -d
```

### Method 3: Docker Registry (Best for Teams)

Push to Docker Hub or private registry:

```bash
# Tag and push
docker tag romasub-ai-backend:latest username/romasub-ai:latest
docker push username/romasub-ai:latest

# Colleague pulls and runs
docker pull username/romasub-ai:latest
docker-compose up -d
```

---

## FAQ

**Q: Do I need to install Python or PostgreSQL separately?**
A: No! Docker containers include everything. You only need Docker installed.

**Q: Will my data be lost if I stop containers?**
A: No. Data is stored in Docker volumes and persists between restarts. Only `docker-compose down -v` deletes data.

**Q: Can I run this alongside the non-Docker version?**
A: Yes, but change the ports to avoid conflicts (e.g., use 8001 instead of 8000).

**Q: How do I update to the latest code?**
A: `git pull` then `docker-compose up -d --build`

**Q: How much disk space is needed?**
A: Approximately 5-10 GB for images, plus space for uploaded files and database.

**Q: Can I use Docker on Windows?**
A: Yes! Install Docker Desktop for Windows. Make sure WSL 2 is enabled.

---

## Support

For issues:
1. Check container logs: `docker-compose logs`
2. Verify containers are running: `docker-compose ps`
3. Check Docker system: `docker system info`
4. Review this guide's Troubleshooting section

---

## Summary

```bash
# Quick reference card
docker-compose up -d          # Start everything
docker-compose ps             # Check status
docker-compose logs -f        # View logs
docker-compose stop           # Stop containers
docker-compose down           # Stop and remove containers
docker-compose down -v        # Remove everything including data
docker-compose restart backend # Restart backend
docker-compose up -d --build  # Rebuild and restart
```

---

**Project:** RomaSub.AI - Roman Urdu Captions Generator
**Team:** Muttayyab Abdurrehman, Muhammad Hashir, Muneeb Khan
**Supervisor:** Dr. Osman Khalid
**Institution:** COMSATS University Islamabad, Abbottabad Campus

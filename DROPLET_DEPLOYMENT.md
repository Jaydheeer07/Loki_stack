# Loki Stack Deployment Guide for DigitalOcean Droplet

This guide walks you through deploying the Loki logging stack on a DigitalOcean Droplet running Ubuntu 24.04.

## Prerequisites

- DigitalOcean Droplet (2 GB Memory / 60 GB Disk / Ubuntu 24.04)
- SSH access to the Droplet
- Repository pushed to GitHub (public or private with access)

## Quick Deployment

### Step 1: SSH into your Droplet

```bash
ssh root@YOUR_DROPLET_IP
```

### Step 2: Set environment variables and run deployment script

```bash
# Set your repository URL
export REPO_URL='https://github.com/YOUR_USERNAME/Loki_stack.git'

# Optional: Set custom Grafana credentials
export GF_ADMIN_USER='admin'
export GF_ADMIN_PASSWORD='your_secure_password'

# Download and run the deployment script
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/Loki_stack/main/deploy-droplet.sh | bash
```

Or manually:

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/Loki_stack.git /opt/loki-stack
cd /opt/loki-stack

# Make the script executable and run it
chmod +x deploy-droplet.sh
sudo ./deploy-droplet.sh
```

## Manual Deployment Steps

If you prefer to run commands manually:

### 1. Update System

```bash
sudo apt-get update && sudo apt-get upgrade -y
```

### 2. Install Docker

```bash
# Install prerequisites
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker
```

### 3. Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/Loki_stack.git /opt/loki-stack
cd /opt/loki-stack
```

### 4. Create .env File

```bash
cat > .env << EOF
GF_ADMIN_USER=admin
GF_ADMIN_PASSWORD=your_secure_password_here
EOF

chmod 600 .env
```

### 5. Create Data Directories

```bash
mkdir -p loki-data grafana-data
chown -R 472:472 grafana-data
chown -R 10001:10001 loki-data
```

### 6. Configure Firewall

```bash
sudo ufw enable
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 3000/tcp  # Grafana
sudo ufw allow 9000/tcp  # Vector (log ingestion)
sudo ufw reload
```

### 7. Start the Stack

```bash
docker compose up -d
```

## Accessing Services

| Service | URL | Purpose |
|---------|-----|---------|
| Grafana | `http://YOUR_DROPLET_IP:3000` | Dashboard & visualization |
| Vector | `http://YOUR_DROPLET_IP:9000` | Log ingestion endpoint |
| Loki | `http://YOUR_DROPLET_IP:3100` | Log storage (internal) |

## Updating DigitalOcean Log Forwarding

After deployment, update your DigitalOcean App Platform log forwarding to point to the Droplet:

1. Go to DigitalOcean Console → Apps → Your App → Settings → Log Forwarding
2. Update the OpenSearch endpoint to: `http://YOUR_DROPLET_IP:9000`
3. Save changes

## Security Recommendations

### 1. Change Default Grafana Password
Log into Grafana and change the admin password immediately.

### 2. Set Up SSL/TLS (Recommended)

Option A: **Cloudflare Tunnel** (easiest, no open ports needed)
```bash
# Uncomment cloudflared service in docker-compose.yml
# Set CLOUDFLARE_TUNNEL_TOKEN in .env
docker compose up -d
```

Option B: **Nginx Reverse Proxy with Let's Encrypt**
```bash
sudo apt-get install -y nginx certbot python3-certbot-nginx

# Configure nginx for your domain
# Then run certbot for SSL
sudo certbot --nginx -d your-domain.com
```

### 3. Restrict Firewall Access
Consider restricting access to specific IPs:
```bash
# Allow Grafana only from your IP
sudo ufw delete allow 3000/tcp
sudo ufw allow from YOUR_IP to any port 3000

# Allow Vector only from DigitalOcean App Platform IPs
sudo ufw delete allow 9000/tcp
sudo ufw allow from 0.0.0.0/0 to any port 9000  # Or specific DO IP ranges
```

## Useful Commands

```bash
# View all container logs
cd /opt/loki-stack && docker compose logs -f

# View specific service logs
docker compose logs -f grafana
docker compose logs -f loki
docker compose logs -f vector

# Restart services
docker compose restart

# Stop all services
docker compose down

# Update and restart
git pull && docker compose up -d

# Check container status
docker compose ps

# Check disk usage
df -h
docker system df
```

## Troubleshooting

### Services not starting
```bash
# Check logs
docker compose logs

# Check if ports are in use
sudo netstat -tlnp | grep -E '3000|3100|9000'
```

### Permission errors on data directories
```bash
sudo chown -R 472:472 /opt/loki-stack/grafana-data
sudo chown -R 10001:10001 /opt/loki-stack/loki-data
```

### Out of disk space
```bash
# Clean up Docker
docker system prune -a

# Check Loki data size
du -sh /opt/loki-stack/loki-data
```

### Memory issues (2GB Droplet)
If you experience OOM issues, consider:
- Reducing Loki cache size in `loki-config.yaml`
- Adding swap space:
```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## Resource Usage Notes

With 2GB RAM, the stack should run fine for moderate log volumes. Monitor with:
```bash
docker stats
free -h
```

Consider upgrading to 4GB RAM if you experience performance issues with high log volumes.

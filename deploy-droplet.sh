#!/bin/bash
# Loki Stack Deployment Script for Ubuntu 24.04 Droplet
# Run this script on your DigitalOcean Droplet after SSH'ing in

set -e

echo "=========================================="
echo "Loki Stack Deployment for DigitalOcean"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="${REPO_URL:-}"
INSTALL_DIR="/opt/loki-stack"
GF_ADMIN_USER="${GF_ADMIN_USER:-admin}"
GF_ADMIN_PASSWORD="${GF_ADMIN_PASSWORD:-}"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root (use sudo)"
    exit 1
fi

# Step 1: Update system
print_status "Updating system packages..."
apt-get update && apt-get upgrade -y

# Step 2: Install Docker if not present
if ! command -v docker &> /dev/null; then
    print_status "Installing Docker..."
    
    # Install prerequisites
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    print_status "Docker installed successfully"
else
    print_status "Docker already installed"
fi

# Step 3: Install Git if not present
if ! command -v git &> /dev/null; then
    print_status "Installing Git..."
    apt-get install -y git
fi

# Step 4: Clone or update repository
if [ -z "$REPO_URL" ]; then
    print_warning "REPO_URL not set. Please set it before running:"
    print_warning "  export REPO_URL='https://github.com/YOUR_USERNAME/YOUR_REPO.git'"
    print_warning "Or clone manually to $INSTALL_DIR"
    
    # Create directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
else
    if [ -d "$INSTALL_DIR/.git" ]; then
        print_status "Updating existing repository..."
        cd "$INSTALL_DIR"
        git pull
    else
        print_status "Cloning repository..."
        rm -rf "$INSTALL_DIR"
        git clone "$REPO_URL" "$INSTALL_DIR"
    fi
fi

cd "$INSTALL_DIR"

# Step 5: Create .env file if it doesn't exist
if [ ! -f "$INSTALL_DIR/.env" ]; then
    print_status "Creating .env file..."
    
    # Generate a random password if not provided
    if [ -z "$GF_ADMIN_PASSWORD" ]; then
        GF_ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
        print_warning "Generated random Grafana admin password: $GF_ADMIN_PASSWORD"
        print_warning "SAVE THIS PASSWORD! It won't be shown again."
    fi
    
    cat > "$INSTALL_DIR/.env" << EOF
# Grafana Admin Credentials
GF_ADMIN_USER=${GF_ADMIN_USER}
GF_ADMIN_PASSWORD=${GF_ADMIN_PASSWORD}

# Cloudflare Tunnel (optional - uncomment and set if using)
# CLOUDFLARE_TUNNEL_TOKEN=your_tunnel_token_here
EOF
    
    chmod 600 "$INSTALL_DIR/.env"
    print_status ".env file created"
else
    print_status ".env file already exists"
fi

# Step 6: Create data directories with proper permissions
print_status "Creating data directories..."
mkdir -p "$INSTALL_DIR/loki-data"
mkdir -p "$INSTALL_DIR/grafana-data"

# Grafana runs as user 472 inside the container
chown -R 472:472 "$INSTALL_DIR/grafana-data"
# Loki runs as user 10001 inside the container
chown -R 10001:10001 "$INSTALL_DIR/loki-data"

# Step 7: Configure UFW Firewall
print_status "Configuring firewall..."
if command -v ufw &> /dev/null; then
    ufw --force enable
    
    # Allow SSH (important - don't lock yourself out!)
    ufw allow 22/tcp
    
    # Allow Grafana (dashboard access)
    ufw allow 3000/tcp
    
    # Allow Vector HTTP endpoint (for log ingestion)
    ufw allow 9000/tcp
    
    # Optional: Allow Loki direct access (usually not needed if using Grafana)
    # ufw allow 3100/tcp
    
    # Optional: Allow Vector OpenSearch endpoint
    # ufw allow 9001/tcp
    
    ufw reload
    print_status "Firewall configured"
else
    print_warning "UFW not found, skipping firewall configuration"
fi

# Step 8: Start the stack
print_status "Starting Loki stack..."
cd "$INSTALL_DIR"
docker compose down 2>/dev/null || true
docker compose up -d

# Step 9: Wait for services to be healthy
print_status "Waiting for services to start..."
sleep 10

# Check service status
print_status "Checking service status..."
docker compose ps

# Get Droplet IP
DROPLET_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo "=========================================="
echo -e "${GREEN}Deployment Complete!${NC}"
echo "=========================================="
echo ""
echo "Access your services:"
echo "  Grafana Dashboard: http://${DROPLET_IP}:3000"
echo "  Grafana Login: ${GF_ADMIN_USER} / (check .env file for password)"
echo ""
echo "Log ingestion endpoint:"
echo "  Vector HTTP: http://${DROPLET_IP}:9000"
echo ""
echo "Useful commands:"
echo "  View logs:     cd $INSTALL_DIR && docker compose logs -f"
echo "  Stop stack:    cd $INSTALL_DIR && docker compose down"
echo "  Start stack:   cd $INSTALL_DIR && docker compose up -d"
echo "  Update stack:  cd $INSTALL_DIR && git pull && docker compose up -d"
echo ""
print_warning "SECURITY REMINDER: Change the default Grafana password after first login!"
echo ""

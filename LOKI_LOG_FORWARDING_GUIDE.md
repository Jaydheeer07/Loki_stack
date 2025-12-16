# Loki Log Forwarding & MCP Integration Guide

## Overview

This guide sets up a centralized logging solution for the AP Workflow application deployed on DigitalOcean App Platform. It enables AI assistants (like Cascade) to query and analyze Celery worker logs directly through the Model Context Protocol (MCP).

### Problem Statement
- DigitalOcean App Platform logs are only accessible via streaming WebSocket URLs
- Cannot easily query historical logs for debugging CPU overload issues
- AI assistants cannot access logs programmatically

### Solution Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     DigitalOcean App Platform                    │
│  ┌─────────────┐     ┌─────────────┐                            │
│  │  API Prod   │     │ Celery Prod │                            │
│  │ api.dexiq   │     │  (Worker)   │                            │
│  └─────────────┘     └─────────────┘                            │
│         │                   │                                    │
│         └───────────────────┴──── Log Forwarding ────────────┐  │
└──────────────────────────────────────────────────────────────│──┘
                                                               │
                                    (via ngrok or Cloudflare Tunnel)
                                                               │
                                                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Local Docker Stack                            │
│                                                                  │
│  ┌─────────────┐     ┌─────────────┐                            │
│  │   Grafana   │◄────│    Loki     │◄── Receives logs from DO   │
│  │  Port 3000  │     │  Port 3100  │                            │
│  │  (Web UI)   │     │ (Log Store) │                            │
│  └─────────────┘     └─────────────┘                            │
│                             │                                    │
│                             ▼                                    │
│                    ┌─────────────────┐                          │
│                    │  Loki MCP Server │◄── Windsurf/Cascade     │
│                    │   (stdio mode)   │    queries logs here    │
│                    └─────────────────┘                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Progress Tracker

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 1 | ✅ Complete | Local Loki + Grafana + Vector Stack |
| Phase 2 | ✅ Complete | Expose Vector via ngrok |
| Phase 3 | ✅ Complete | Configure DigitalOcean Log Forwarding |
| Phase 4 | ⏳ Pending | Install Loki MCP Server |
| Phase 5 | ⏳ Pending | Using the Loki MCP Server |

---

## Prerequisites

- [x] Docker Desktop installed and running
- [x] ngrok account (free tier)
- [x] DigitalOcean account with App Platform access
- [ ] Go 1.21+ installed (for Loki MCP server) - *Phase 4*
- [ ] Windsurf IDE with MCP support - *Phase 4*

---

## Phase 1: Local Loki + Grafana Stack ✅ COMPLETE

### Step 1.1: Create Directory Structure

```powershell
# Create the logging stack directory
mkdir C:\Users\jaydh\Documents\Projects\loki-stack
cd C:\Users\jaydh\Documents\Projects\loki-stack

# Create subdirectories
mkdir loki-config
mkdir grafana-config
mkdir loki-data
```

### Step 1.2: Create Loki Configuration

Create `loki-config/loki-config.yaml`:

```yaml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  log_level: info

common:
  instance_addr: 127.0.0.1
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h  # 7 days
  ingestion_rate_mb: 16
  ingestion_burst_size_mb: 24
  per_stream_rate_limit: 5MB
  per_stream_rate_limit_burst: 15MB

# Enable push API for DigitalOcean log forwarding
frontend:
  max_outstanding_per_tenant: 4096

ingester:
  chunk_idle_period: 1h
  max_chunk_age: 1h
  chunk_target_size: 1048576
  chunk_retain_period: 30s
```

### Step 1.3: Create Docker Compose File

Create `docker-compose.yml`:

```yaml
version: "3.8"

services:
  loki:
    image: grafana/loki:2.9.3
    container_name: loki
    ports:
      - "3100:3100"
    volumes:
      - ./loki-config/loki-config.yaml:/etc/loki/local-config.yaml:ro
      - ./loki-data:/loki
    command: -config.file=/etc/loki/local-config.yaml
    restart: unless-stopped
    networks:
      - loki-network

  grafana:
    image: grafana/grafana:10.2.3
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - ./grafana-config:/var/lib/grafana
    depends_on:
      - loki
    restart: unless-stopped
    networks:
      - loki-network

  # Cloudflare Tunnel (uncomment after setup)
  # cloudflared:
  #   image: cloudflare/cloudflared:latest
  #   container_name: cloudflared
  #   command: tunnel --no-autoupdate run
  #   environment:
  #     - TUNNEL_TOKEN=${CLOUDFLARE_TUNNEL_TOKEN}
  #   restart: unless-stopped
  #   networks:
  #     - loki-network

networks:
  loki-network:
    driver: bridge
```

### Step 1.4: Create Environment File

Create `.env`:

```env
# Cloudflare Tunnel Token (add after creating tunnel)
CLOUDFLARE_TUNNEL_TOKEN=

# Grafana credentials
GF_ADMIN_USER=admin
GF_ADMIN_PASSWORD=admin123
```

### Step 1.5: Start the Stack

```powershell
cd C:\Users\jaydh\Documents\Projects\Jaydheeeer_Github_Projects\Loki_stack
docker-compose up -d

# Verify services are running
docker-compose ps

# Check Loki is ready
Invoke-RestMethod -Uri "http://localhost:3100/ready" -Method Get
# Expected output: ready
```

### Step 1.6: Verify Grafana Data Source

The Loki datasource is **auto-configured** via provisioning. To verify:

1. Open http://localhost:3000 in your browser
2. Login with `admin` / `admin123`
3. Go to **Connections** → **Data Sources**
4. You should see **Loki** already configured

### Step 1.7: Test Log Ingestion

```powershell
# Send a test log to Loki
$timestamp = [string]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() * 1000000)
$json = '{"streams":[{"stream":{"job":"test","source":"manual"},"values":[["' + $timestamp + '","Test log message - Loki is working!"]]}]}'
Invoke-RestMethod -Uri "http://localhost:3100/loki/api/v1/push" -Method Post -Body $json -ContentType "application/json"

# Query the test log
Invoke-RestMethod -Uri 'http://localhost:3100/loki/api/v1/query?query={job="test"}' -Method Get
```

### Phase 1 Results

| Component | Status | Access URL |
|-----------|--------|------------|
| Loki | ✅ Running | http://localhost:3100 |
| Grafana | ✅ Running | http://localhost:3000 |
| Test Log | ✅ Verified | Successfully pushed and queried |

### Files Created

```
Loki_stack/
├── docker-compose.yml
├── .env
├── .gitignore
├── LOKI_LOG_FORWARDING_GUIDE.md
├── loki-config/
│   └── loki-config.yaml
├── grafana-provisioning/
│   └── datasources/
│       └── loki.yaml
├── grafana-data/          (auto-created, gitignored)
└── loki-data/             (auto-created, gitignored)
```

---

## Phase 2: Expose Loki to the Internet ✅ COMPLETE

To receive logs from DigitalOcean, Loki needs to be accessible from the internet. We have two options:

### Option A: ngrok (Quick Setup - Currently Active) ✅

**What is ngrok?**
ngrok is a tunneling service that exposes your local server to the internet. It creates a secure tunnel from a public URL to your localhost.

```
Internet Request                Your Local Machine
       │                              │
       ▼                              ▼
┌─────────────────┐           ┌─────────────────┐
│  ngrok servers  │◄─────────►│  ngrok client   │
│ (their cloud)   │  tunnel   │ (runs locally)  │
└─────────────────┘           └─────────────────┘
       │                              │
       │                              ▼
       │                      ┌─────────────────┐
       └─────────────────────►│  Loki :3100     │
         https://xxx.ngrok-free.app     
```

#### Step 2A.1: Install ngrok

```powershell
# Install via winget
winget install ngrok.ngrok

# After installation, open a NEW terminal to refresh PATH
```

#### Step 2A.2: Authenticate ngrok

1. Create account at https://ngrok.com
2. Get your authtoken from https://dashboard.ngrok.com/get-started/your-authtoken
3. Configure ngrok:

```powershell
ngrok config add-authtoken YOUR_NGROK_TOKEN
```

#### Step 2A.3: Start ngrok Tunnel

```powershell
# Update ngrok to latest version (required for free accounts)
ngrok update

# Start the tunnel
ngrok http 3100
```

#### Step 2A.4: Note Your Public URL

ngrok will display output like:
```
Session Status                online
Account                       Your Name (Plan: Free)
Version                       3.34.0
Region                        Asia Pacific (ap)
Forwarding                    https://xxxxx.ngrok-free.app -> http://localhost:3100
```

**Your Loki Public URL**: `https://xxxxx.ngrok-free.app`

#### ngrok Limitations (Free Tier)

| Limitation | Impact |
|------------|--------|
| URL changes on restart | Need to update DigitalOcean config each time |
| Interstitial warning page | May affect some API integrations |
| Rate limits | Sufficient for log forwarding |

#### Verify ngrok is Working

```powershell
# Test with ngrok-skip-browser-warning header
$headers = @{ "ngrok-skip-browser-warning" = "true" }
Invoke-RestMethod -Uri "https://YOUR-URL.ngrok-free.app/ready" -Headers $headers -Method Get
# Expected output: ready
```

### Phase 2 Results (ngrok)

| Item | Value |
|------|-------|
| Public URL | `https://clankingly-stirruplike-ethelene.ngrok-free.dev` |
| Loki Push API | `https://clankingly-stirruplike-ethelene.ngrok-free.dev/loki/api/v1/push` |
| ngrok Dashboard | http://127.0.0.1:4040 |
| Status | ✅ Active (keep terminal running) |

---

### Option B: Cloudflare Tunnel (Production - Recommended for Long-term)

For a permanent, stable solution, use Cloudflare Tunnel. This requires coordination with IT if using company domain.

#### Step 2B.1: Create Cloudflare Tunnel

1. Go to https://one.dash.cloudflare.com/
2. Navigate to **Networks** → **Tunnels**
3. Click **Create a tunnel**
4. Name it: `loki-log-forwarder`
5. Copy the tunnel token

#### Step 2B.2: Configure Tunnel Route

In the Cloudflare dashboard, add a public hostname:
- **Subdomain**: `loki-logs`
- **Domain**: Your domain (e.g., `dexiq.com.au`)
- **Service**: `http://loki:3100`

#### Step 2B.3: Update Docker Compose

Uncomment the `cloudflared` service in `docker-compose.yml` and add your token to `.env`:

```env
CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoiYWJjZGVmLi4uIiwidCI6Ii4uLiIsInMiOiIuLi4ifQ==
```

Restart the stack:
```powershell
docker-compose up -d
```

Your Loki endpoint will be: `https://loki-logs.dexiq.com.au`

#### Cloudflare vs ngrok Comparison

| Feature | ngrok (Free) | Cloudflare Tunnel |
|---------|--------------|-------------------|
| Cost | Free | Free |
| Static URL | ❌ Changes on restart | ✅ Permanent |
| Custom domain | ❌ No | ✅ Yes |
| Interstitial page | ⚠️ Yes | ✅ No |
| Setup complexity | Easy | Requires IT/DNS |
| Recommended for | Testing | Production |

---

## Phase 3: Configure DigitalOcean Log Forwarding ✅ COMPLETE

### Architecture with Vector

Since DigitalOcean sends logs in OpenSearch format (not Loki format), we use **Vector** as a log transformer:

```
DigitalOcean App Platform
         │
         │ (OpenSearch bulk format)
         ▼
    ngrok tunnel
         │
         ▼
┌─────────────────┐
│     Vector      │ ← Receives OpenSearch format
│   (port 9000)   │ ← Transforms to Loki format
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│      Loki       │ ← Stores logs
│   (port 3100)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    Grafana      │ ← Query & visualize
│   (port 3000)   │
└─────────────────┘
```

### Current ngrok URL

```
https://clankingly-stirruplike-ethelene.ngrok-free.dev
```

> ⚠️ **Important**: This URL changes every time ngrok restarts. Update DigitalOcean config accordingly.

### Step 3.1: Configure via DigitalOcean Control Panel

1. Go to https://cloud.digitalocean.com/apps/28911d1a-c48a-4549-8f1e-280f52c74d0d/settings
2. Scroll to **Log Forwarding** section
3. Click **Edit** or **Add Destination**
4. Select **OpenSearch** (External)
5. Configure:
   - **Endpoint**: `https://clankingly-stirruplike-ethelene.ngrok-free.dev`
   - **Index Name**: `logs`
   - **Username**: (leave empty)
   - **Password**: (leave empty)
6. Select components: `api-prod`, `celery-prod`
7. Click **Add Log Destination**

### Step 3.2: Via App Spec (Alternative)

Add to your app spec YAML:

```yaml
log_destinations:
  - name: vector-loki
    open_search:
      endpoint: https://clankingly-stirruplike-ethelene.ngrok-free.dev
      index_name: logs
```

### Step 3.3: Verify Logs Are Arriving

```powershell
# 1. Check ngrok dashboard for incoming requests
# Open http://127.0.0.1:4040 in browser - you should see POST requests

# 2. Check Vector logs for incoming data
docker logs vector --tail 20

# 3. Query Loki for DigitalOcean logs
Invoke-RestMethod -Uri 'http://localhost:3100/loki/api/v1/query?query={job="digitalocean"}' -Method Get

# 4. Or check in Grafana Explore tab at http://localhost:3000
```

### Test Vector Manually

Before configuring DigitalOcean, test that Vector is working:

```powershell
# Send a test log (simulating DigitalOcean format)
$headers = @{ "ngrok-skip-browser-warning" = "true"; "Content-Type" = "application/json" }
$body = '{"message": "Test log from manual test", "component": "celery-prod", "level": "info"}'
Invoke-RestMethod -Uri "https://clankingly-stirruplike-ethelene.ngrok-free.dev/" -Method Post -Body $body -Headers $headers

# Verify it arrived in Loki
Invoke-RestMethod -Uri 'http://localhost:3100/loki/api/v1/query?query={job="digitalocean"}' -Method Get
```

### Known Limitations

| Issue | Description | Workaround |
|-------|-------------|------------|
| ngrok interstitial | Free tier shows warning page for browsers | API calls work fine |
| URL changes | ngrok URL changes on restart | Use Cloudflare for production |
| ngrok free limits | Rate limits apply | Sufficient for log forwarding |

### Files Created in This Phase

```
Loki_stack/
├── vector-config/
│   └── vector.yaml    # Vector configuration for log transformation
```

---

## Phase 4: Install Loki MCP Server

### Step 4.1: Install the Official Grafana Loki MCP Server

```powershell
# Clone the repository
cd C:\Users\jaydh\Documents\Projects
git clone https://github.com/grafana/loki-mcp.git
cd loki-mcp

# Build the server
go build -o loki-mcp.exe ./cmd/loki-mcp

# Move to a permanent location
mkdir C:\tools\mcp-servers
copy loki-mcp.exe C:\tools\mcp-servers\
```

### Step 4.2: Configure Windsurf MCP

Update `C:\Users\jaydh\.codeium\windsurf\mcp_config.json`:

```json
{
  "mcpServers": {
    "loki": {
      "command": "C:\\tools\\mcp-servers\\loki-mcp.exe",
      "args": [],
      "env": {
        "LOKI_URL": "http://localhost:3100",
        "LOKI_ORG_ID": ""
      }
    }
    // ... other servers
  }
}
```

### Step 4.3: Restart Windsurf

Close and reopen Windsurf to load the new MCP server.

---

## Phase 5: Using the Loki MCP Server

### Available Tools

Once configured, the Loki MCP server provides these tools:

| Tool | Description |
|------|-------------|
| `query_logs` | Query logs using LogQL |
| `query_range` | Query logs over a time range |
| `get_labels` | List all available labels |
| `get_label_values` | Get values for a specific label |
| `get_series` | Get log series matching a selector |

### Example Queries

**Query Celery worker logs:**
```logql
{job="digitalocean", component="celery-prod"} |= "ERROR"
```

**Find CPU-related issues:**
```logql
{component="celery-prod"} |~ "(?i)(cpu|memory|timeout|killed)"
```

**Query last hour of errors:**
```logql
{component="celery-prod"} |= "ERROR" | json | line_format "{{.message}}"
```

**Find slow tasks:**
```logql
{component="celery-prod"} |~ "Task.*succeeded in [0-9]{2,}\\.[0-9]+ seconds"
```

---

## Troubleshooting

### Loki Not Receiving Logs

1. Check Cloudflare Tunnel status:
   ```powershell
   docker logs cloudflared
   ```

2. Verify Loki is accepting connections:
   ```powershell
   curl http://localhost:3100/ready
   ```

3. Check DigitalOcean log forwarding status in the control panel

### MCP Server Not Connecting

1. Verify the executable exists:
   ```powershell
   Test-Path C:\tools\mcp-servers\loki-mcp.exe
   ```

2. Test manually:
   ```powershell
   $env:LOKI_URL="http://localhost:3100"
   C:\tools\mcp-servers\loki-mcp.exe
   ```

3. Check Windsurf MCP logs

### High Memory Usage

Adjust Loki retention in `loki-config.yaml`:
```yaml
limits_config:
  retention_period: 72h  # Reduce from 7 days to 3 days
```

---

## Maintenance

### Backup Loki Data

```powershell
# Stop Loki
docker-compose stop loki

# Backup data
Compress-Archive -Path .\loki-data -DestinationPath loki-backup-$(Get-Date -Format "yyyy-MM-dd").zip

# Restart
docker-compose start loki
```

### Clear Old Logs

```powershell
# Stop Loki
docker-compose stop loki

# Clear data (WARNING: deletes all logs)
Remove-Item -Recurse -Force .\loki-data\*

# Restart
docker-compose start loki
```

### Update Stack

```powershell
docker-compose pull
docker-compose up -d
```

---

## Security Considerations

1. **Never expose Loki directly to the internet** - Always use Cloudflare Tunnel or VPN
2. **Enable authentication** if exposing publicly:
   ```yaml
   # In loki-config.yaml
   auth_enabled: true
   ```
3. **Rotate Cloudflare Tunnel tokens** periodically
4. **Use strong Grafana passwords** in production

---

## Cost Estimate

| Component | Cost |
|-----------|------|
| Local Docker Stack | Free (uses local resources) |
| Cloudflare Tunnel | Free tier |
| DigitalOcean Log Forwarding | Free (included in App Platform) |
| **Total** | **$0/month** |

---

## Next Steps

After completing this setup:

1. [ ] Verify logs are flowing from DigitalOcean to Loki
2. [ ] Create Grafana dashboards for Celery worker metrics
3. [ ] Set up alerts for CPU/memory issues
4. [ ] Use Cascade to query logs and debug the CPU overload issue

---

## References

- [Grafana Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Grafana Loki MCP Server](https://github.com/grafana/loki-mcp)
- [DigitalOcean Log Forwarding](https://docs.digitalocean.com/products/app-platform/how-to/forward-logs/)
- [Cloudflare Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [LogQL Query Language](https://grafana.com/docs/loki/latest/query/)

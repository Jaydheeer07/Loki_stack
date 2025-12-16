# Loki Stack Startup Script
# Run this script to start the entire logging stack

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Loki Stack Startup Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Start Docker containers
Write-Host "[1/3] Starting Docker containers..." -ForegroundColor Yellow
docker-compose up -d

# Wait for containers to be healthy
Write-Host "[2/3] Waiting for containers to be healthy..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Check container status
docker-compose ps

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Containers Started!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Access Points:" -ForegroundColor Cyan
Write-Host "  - Grafana:    http://localhost:3000 (admin/admin123)" -ForegroundColor White
Write-Host "  - Loki API:   http://localhost:3100" -ForegroundColor White
Write-Host "  - Vector:     http://localhost:9000" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  IMPORTANT: Start ngrok manually!" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Run this command in a NEW terminal:" -ForegroundColor White
Write-Host ""
Write-Host "  ngrok http 9000" -ForegroundColor Green
Write-Host ""
Write-Host "Or with a static domain (recommended):" -ForegroundColor White
Write-Host ""
Write-Host "  ngrok http 9000 --domain=YOUR-STATIC-DOMAIN.ngrok-free.app" -ForegroundColor Green
Write-Host ""
Write-Host "After starting ngrok, if the URL changed, update DigitalOcean:" -ForegroundColor Yellow
Write-Host "  https://cloud.digitalocean.com/apps/28911d1a-c48a-4549-8f1e-280f52c74d0d/settings" -ForegroundColor White
Write-Host ""

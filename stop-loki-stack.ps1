# Loki Stack Shutdown Script
# Run this script to stop the entire logging stack

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Loki Stack Shutdown Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Stopping Docker containers..." -ForegroundColor Yellow
docker-compose down

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Containers Stopped!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Don't forget to stop ngrok (Ctrl+C in ngrok terminal)" -ForegroundColor Yellow
Write-Host ""

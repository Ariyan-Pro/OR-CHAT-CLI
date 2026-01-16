
ORCHAT Operations Guide
Enterprise Deployment & Management
Monitoring
Metrics
ORCHAT exposes Prometheus metrics at http://localhost:9090/metrics

Key Metrics:

orchat_requests_total - Total API requests

orchat_errors_total - Error count by type

orchat_response_time_seconds - Response time histogram

orchat_tokens_total - Token usage

orchat_memory_bytes - Memory usage

Example Queries:

promql
# Error rate (5-minute average)
rate(orchat_errors_total[5m])

# 95th percentile response time
histogram_quantile(0.95, rate(orchat_response_time_seconds_bucket[5m]))

# Memory usage trend
rate(orchat_memory_bytes[1h])
Logs
ORCHAT uses structured JSON logging with 13 severity levels.

Log Locations:

System: /var/log/orchat/orchat.log

User: ~/.cache/orchat/logs/orchat.log

Rotation: Daily, 100MB max, 30 day retention

Log Levels:

-1: Quantum (internal tracing)

0: Trace

1: Debug

3: Info (default)

6: Error

9: Emergency

Configuration:

bash
# Set log level
export ORCHAT_LOG_LEVEL=1  # Debug mode

# Change log location
export ORCHAT_LOG_FILE=/path/to/custom.log
Health Checks
Built-in Health Check
bash
# Run comprehensive health check
orchat health-check

# Check specific component
orchat health-check --component=api
orchat health-check --component=filesystem
orchat health-check --component=network
Health Check Output:

text
✅ API: Reachable (latency: 45ms)
✅ Filesystem: Writeable (85% free)
✅ Network: Connected (stable)
⚠️  Memory: 78% usage (monitor)
❌ Database: Connection failed (check credentials)
Custom Health Checks
Create ~/.config/orchat/health-checks.yaml:

yaml
checks:
  - name: "API Endpoint"
    command: "curl -sSf https://api.openrouter.ai/v1/models"
    timeout: 10
    interval: 60
    
  - name: "Disk Space"
    command: "df / | awk 'NR==2 {print $5}' | tr -d '%'"
    warning: "> 80"
    critical: "> 90"
    
  - name: "Service Status"
    command: "systemctl is-active orchat"
    expect: "active"
Backup & Recovery
Configuration Backup
bash
# Backup all configuration
mkdir -p ~/backup/orchat
cp -r ~/.config/orchat ~/backup/orchat/config-$(date +%Y%m%d)
cp ~/.orchat_history ~/backup/orchat/history-$(date +%Y%m%d)

# Automated backup script
cat > /etc/cron.daily/orchat-backup << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/orchat/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"
cp -r /home/*/.config/orchat "$BACKUP_DIR/" 2>/dev/null || true
cp -r /home/*/.orchat_history "$BACKUP_DIR/" 2>/dev/null || true
find /backup/orchat -type d -mtime +30 -exec rm -rf {} \;
EOF
chmod +x /etc/cron.daily/orchat-backup
Disaster Recovery
bash
# Full restore procedure
1. Install ORCHAT: curl -fsSL https://orchat.ai/install.sh | bash
2. Restore config: cp -r ~/backup/orchat/config-latest/* ~/.config/orchat/
3. Restore history: cp ~/backup/orchat/history-latest ~/.orchat_history
4. Verify: orchat health-check --full
Performance Tuning
Memory Optimization
bash
# Reduce memory footprint
export ORCHAT_MAX_HISTORY=5  # Default: 10
export ORCHAT_STREAM_BUFFER=4096  # Default: 8192
export ORCHAT_CACHE_SIZE=100  # MB, Default: 500

# Enable memory limits
ulimit -v 1000000  # 1GB virtual memory limit
Network Optimization
bash
# Adjust timeouts
export ORCHAT_REQUEST_TIMEOUT=45  # Default: 30
export ORCHAT_CONNECT_TIMEOUT=15  # Default: 10
export ORCHAT_RETRY_ATTEMPTS=3    # Default: 2

# Enable keepalive
export ORCHAT_TCP_KEEPALIVE=1
Security
API Key Rotation
bash
# Rotate keys monthly
# 1. Generate new key at https://openrouter.ai/keys
# 2. Update config
echo "sk-or-new-key" > ~/.config/orchat/config
chmod 600 ~/.config/orchat/config

# 3. Verify old key still works (grace period)
# 4. Disable old key after 7 days
Audit Logging
bash
# Enable audit mode
export ORCHAT_AUDIT_LOG=1
export ORCHAT_AUDIT_FILE=/var/log/orchat/audit.log

# Audit log format:
# TIMESTAMP | USER | COMMAND | RESOURCE | STATUS
Scaling
Multiple Instances
bash
# Run multiple ORCHAT instances
for i in {1..4}; do
  PORT=$((9090 + i))
  ORCHAT_INSTANCE_NAME="orchat-$i" \
  ORCHAT_METRICS_PORT="$PORT" \
  orchat --daemon &
done

# Load balancer configuration
# Use nginx/haproxy to distribute requests
High Availability
bash
# Keepalived configuration example
vrrp_script check_orchat {
  script "pgrep -f 'orchat --daemon'"
  interval 2
  weight 2
}

vrrp_instance VI_1 {
  state MASTER
  interface eth0
  virtual_router_id 51
  priority 100
  advert_int 1
  
  virtual_ipaddress {
    192.168.1.100
  }
  
  track_script {
    check_orchat
  }
}
Maintenance
Log Rotation
bash
# Systemd journal configuration
cat > /etc/systemd/journald.conf.d/orchat.conf << 'EOF'
[Journal]
Storage=persistent
SystemMaxUse=1G
SystemKeepFree=2G
SystemMaxFileSize=100M
MaxFileSec=1day
Compress=yes
EOF
systemctl restart systemd-journald
Update Procedure
bash
# Safe update process
1. Backup: orchat backup create --full
2. Check compatibility: orchat health-check --pre-upgrade
3. Update: curl -fsSL https://orchat.ai/install.sh | bash -s -- --upgrade
4. Verify: orchat --version && orchat health-check
5. Rollback if needed: orchat backup restore latest
Support Contacts
24/7 Support: support@orchat.ai

Security Issues: security@orchat.ai

Documentation: https://docs.orchat.ai

Status Page: https://status.orchat.ai

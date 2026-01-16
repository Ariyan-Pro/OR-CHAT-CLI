
ORCHAT Failure Modes
Diagnosis and Resolution Guide
Exit Code Reference
CodeNameMeaningSeverity
0E_OKSuccessInfo
1E_KEY_MISSINGAPI key not configuredCritical
2E_INPUT_MISSINGNo prompt providedWarning
3E_NETWORK_FAILNetwork connectivity issueCritical
4E_API_FAILAPI error responseError
5E_PARSE_FAILJSON parsing failureError
6E_INVALID_INPUTInput validation failedWarning
7E_DEPENDENCYMissing dependency (curl/jq)Critical
8E_CONFIGConfiguration errorError
9E_PERMISSIONPermission deniedCritical
10E_TIMEOUTOperation timed outError
11E_RESOURCEResource exhaustedCritical
12E_INTERNALInternal errorCritical
13-127ReservedFuture useVaries
128+SignalProcess terminated by signalCritical
Common Failure Scenarios
1. API Key Issues
Symptom: Exit code 1, "API key not configured"
Detection:

bash
orchat "test" 2>&1 | grep -i "api.*key"
# OR
echo $?  # Returns 1
Causes:

Environment variable not set

Config file missing or corrupted

Key revoked or expired

Permission issues on config file

Resolution:

bash
# 1. Verify key exists
cat ~/.config/orchat/config 2>/dev/null || echo "No config"

# 2. Test key validity
curl -s -H "Authorization: Bearer $(cat ~/.config/orchat/config)" \
  https://openrouter.ai/api/v1/models | jq .error 2>/dev/null

# 3. Reset configuration
rm -rf ~/.config/orchat
mkdir -p ~/.config/orchat
echo "sk-or-your-key" > ~/.config/orchat/config
chmod 600 ~/.config/orchat/config

# 4. Test
export OPENROUTER_API_KEY="sk-or-your-key"
orchat "test"
2. Network Failures
Symptom: Exit code 3, "Network connectivity failure"
Detection:

bash
# Test connectivity
curl -sSf https://openrouter.ai/api/v1/models >/dev/null
echo $?  # Non-zero indicates failure
Causes:

Internet connection down

DNS resolution failure

Firewall blocking requests

Proxy misconfiguration

API service outage

Resolution:

bash
# 1. Basic network diagnostics
ping -c 3 8.8.8.8
curl -v https://openrouter.ai/health

# 2. Check DNS
nslookup api.openrouter.ai
dig api.openrouter.ai

# 3. Test with different endpoints
export OPENROUTER_API_BASE="https://api.openrouter.ai"
orchat "test"

# 4. Configure proxy if needed
export https_proxy="http://proxy:3128"
export http_proxy="http://proxy:3128"

# 5. Check firewall
sudo iptables -L -n | grep openrouter
3. Dependency Issues
Symptom: Exit code 7, "Missing dependency"
Detection:

bash
# Check required tools
command -v curl && echo "✅ curl" || echo "❌ curl"
command -v jq && echo "✅ jq" || echo "❌ jq"
command -v python3 && echo "✅ python3" || echo "❌ python3"
Causes:

Package not installed

PATH configuration incorrect

Version mismatch

Broken installation

Resolution:

bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y curl jq python3 python3-pip

# macOS
brew update
brew install curl jq python3

# Arch Linux
sudo pacman -Syu curl jq python

# Verify installations
curl --version
jq --version
python3 --version
4. Permission Denied
Symptom: Exit code 9, "Permission denied"
Detection:

bash
ls -la ~/.config/orchat/config
ls -la ~/.local/bin/orchat
Causes:

Config file not readable

Binary not executable

Home directory permissions

Running as wrong user

Resolution:

bash
# 1. Fix config permissions
chmod 600 ~/.config/orchat/config
chmod 700 ~/.config/orchat

# 2. Fix binary permissions
chmod +x ~/.local/bin/orchat

# 3. Check directory ownership
ls -ld ~/.config ~/.local/bin

# 4. Run as correct user
sudo -u $(whoami) orchat "test"
5. Resource Exhaustion
Symptom: Exit code 11, "Resource exhausted"
Detection:

bash
# Check system resources
free -h | grep Mem
df -h | grep -E "/$|/home"
ulimit -a
Causes:

Memory limit reached

Disk space full

File descriptor limit

Process limit

Resolution:

bash
# 1. Increase memory limits
ulimit -v unlimited  # Remove virtual memory limit
export ORCHAT_MAX_MEMORY=2000  # 2GB limit

# 2. Clean up disk space
rm -rf ~/.cache/orchat/old_logs*
find ~/.cache/orchat -name "*.log" -mtime +7 -delete

# 3. Increase file descriptors
ulimit -n 65536
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# 4. Reduce ORCHAT resource usage
export ORCHAT_STREAM_BUFFER=2048  # Smaller buffer
export ORCHAT_MAX_HISTORY=3  # Keep less history
6. Configuration Errors
Symptom: Exit code 8, "Configuration error"
Detection:

bash
# Validate config syntax
python3 -m json.tool ~/.config/orchat/settings.json 2>/dev/null
Causes:

Invalid JSON syntax

Missing required fields

Type mismatches

Outdated schema

Resolution:

bash
# 1. Backup current config
cp ~/.config/orchat/settings.json ~/.config/orchat/settings.json.backup

# 2. Reset to defaults
cat > ~/.config/orchat/settings.json << 'EOF'
{
  "api": {
    "timeout": 30,
    "retries": 2,
    "model": "openai/gpt-3.5-turbo"
  },
  "features": {
    "streaming": true,
    "history": true,
    "metrics": true
  }
}
EOF

# 3. Validate
orchat --validate-config

# 4. Restore custom settings incrementally
Advanced Diagnostics
Debug Mode
bash
# Enable full debugging
export ORCHAT_DEBUG=1
export ORCHAT_LOG_LEVEL=0  # TRACE
orchat "test" 2>&1 | tee debug.log

# Analyze debug output
grep -E "(ERROR|WARN|DEBUG)" debug.log
Performance Profiling
bash
# Time execution
time orchat "Write a 1000 word essay" > /dev/null

# Memory profiling
/usr/bin/time -v orchat "test" 2>&1 | grep -E "Maximum resident"

# Network profiling
export ORCHAT_CURL_VERBOSE=1
orchat "test" 2>&1 | grep -E "(Connected|Send|Recv)"
Health Check Automation
bash
# Automated health monitoring script
cat > /etc/cron.hourly/orchat-health << 'EOF'
#!/bin/bash
LOG="/var/log/orchat/health.log"
STATUS=$(orchat health-check --quiet 2>&1)

if [ $? -ne 0 ]; then
  echo "$(date): CRITICAL - $STATUS" >> "$LOG"
  # Send alert
  curl -X POST https://hooks.slack.com/services/... \
    -d "{\"text\":\"ORCHAT Health Check Failed: $STATUS\"}"
else
  echo "$(date): OK" >> "$LOG"
fi
EOF
chmod +x /etc/cron.hourly/orchat-health
Recovery Procedures
Complete System Reset
bash
# 1. Stop all ORCHAT processes
pkill -f orchat
sleep 2

# 2. Remove all configuration
rm -rf ~/.config/orchat
rm -rf ~/.cache/orchat
rm -f ~/.orchat_history

# 3. Remove binary
rm -f ~/.local/bin/orchat
rm -f /usr/local/bin/orchat

# 4. Clean restart
curl -fsSL https://orchat.ai/install.sh | bash
orchat --setup
Data Recovery
bash
# Recover corrupted history
if [ -f ~/.orchat_history ]; then
  # Backup corrupted file
  cp ~/.orchat_history ~/.orchat_history.corrupted.$(date +%s)
  
  # Attempt repair
  python3 -c "
  import json
  with open('~/.orchat_history.corrupted', 'r') as f:
      try:
          data = json.load(f)
          with open('~/.orchat_history', 'w') as out:
              json.dump(data, out, indent=2)
          print('Repair successful')
      except:
          print('Could not repair, starting fresh')
          with open('~/.orchat_history', 'w') as out:
              json.dump([], out)
  "
fi
Prevention Best Practices
Regular Backups

bash
# Daily automated backup
0 2 * * * tar -czf /backup/orchat-$(date +\%Y\%m\%d).tar.gz ~/.config/orchat ~/.orchat_history
Monitoring

bash
# Monitor exit codes
echo $? after every ORCHAT command

# Track error rates
grep -c "ERROR" /var/log/orchat/orchat.log
Testing

bash
# Weekly validation suite
0 4 * * 0 cd /path/to/orchat && ./validation/run-all.sh
Updates

bash
# Monthly update check
0 3 1 * * curl -fsSL https://orchat.ai/install.sh | bash -s -- --check-update
Emergency Contacts
Critical Issues: emergency@orchat.ai (24/7)

Technical Support: support@orchat.ai

Security Incidents: security@orchat.ai

Documentation Updates: docs@orchat.ai

Version Compatibility
Current: v0.7.0 (Engineering Freeze)

Minimum: v0.3.0

Breaking changes documented at: https://changelog.orchat.ai

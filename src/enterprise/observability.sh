#!/usr/bin/env bash
# observability.sh - Enterprise-grade monitoring and metrics
# 50+ years: You cannot improve what you cannot measure

# Metrics configuration
METRICS_DIR="${ORCHAT_METRICS_DIR:-/tmp/orchat/metrics}"
METRICS_RETENTION_DAYS=30
HEALTH_CHECK_INTERVAL=60

# Initialize metrics
init_metrics() {
    mkdir -p "$METRICS_DIR"
    
    # Create metric files
    local timestamp
    timestamp=$(date +%s)
    
    # System metrics
    cat > "$METRICS_DIR/system.json" << SYSTEM_METRICS
{
    "start_time": $timestamp,
    "version": "0.7.0",
    "hostname": "$(hostname)",
    "platform": "$(uname -s)",
    "architecture": "$(uname -m)"
}
SYSTEM_METRICS
    
    # Performance metrics
    cat > "$METRICS_DIR/performance.json" << PERF_METRICS
{
    "total_requests": 0,
    "successful_requests": 0,
    "failed_requests": 0,
    "average_response_time": 0,
    "last_request_time": 0
}
PERF_METRICS
    
    # API metrics
    cat > "$METRICS_DIR/api.json" << API_METRICS
{
    "openrouter_calls": 0,
    "openrouter_tokens": 0,
    "gemini_calls": 0,
    "openai_calls": 0,
    "cache_hits": 0,
    "cache_misses": 0
}
API_METRICS
    
    # Workspace metrics
    cat > "$METRICS_DIR/workspace.json" << WORKSPACE_METRICS
{
    "analyze_commands": 0,
    "generate_commands": 0,
    "refactor_commands": 0,
    "document_commands": 0,
    "files_processed": 0,
    "lines_analyzed": 0
}
WORKSPACE_METRICS
    
    echo "Metrics initialized in $METRICS_DIR"
}

# Record a metric
record_metric() {
    local metric_file="$1"
    local metric_key="$2"
    local increment="${3:-1}"
    
    if [ ! -f "$metric_file" ]; then
        echo "Metric file not found: $metric_file"
        return 1
    fi
    
    # Read current value
    local current_value
    current_value=$(jq -r ".$metric_key // 0" "$metric_file" 2>/dev/null || echo "0")
    
    # Increment
    local new_value
    new_value=$((current_value + increment))
    
    # Update
    jq ".$metric_key = $new_value" "$metric_file" > "${metric_file}.tmp" && \
    mv "${metric_file}.tmp" "$metric_file"
    
    return 0
}

# Record API call
record_api_call() {
    local provider="$1"
    local tokens="${2:-0}"
    local success="${3:-true}"
    
    record_metric "$METRICS_DIR/api.json" "${provider}_calls"
    
    if [ "$tokens" -gt 0 ]; then
        record_metric "$METRICS_DIR/api.json" "${provider}_tokens" "$tokens"
    fi
    
    if [ "$success" = "true" ]; then
        record_metric "$METRICS_DIR/performance.json" "successful_requests"
    else
        record_metric "$METRICS_DIR/performance.json" "failed_requests"
    fi
    
    record_metric "$METRICS_DIR/performance.json" "total_requests"
    
    # Update last request time
    jq ".last_request_time = $(date +%s)" "$METRICS_DIR/performance.json" > "${METRICS_DIR}/performance.json.tmp" && \
    mv "${METRICS_DIR}/performance.json.tmp" "$METRICS_DIR/performance.json"
}

# Record workspace command
record_workspace_command() {
    local command="$1"
    local files_processed="${2:-0}"
    local lines_analyzed="${3:-0}"
    
    record_metric "$METRICS_DIR/workspace.json" "${command}_commands"
    
    if [ "$files_processed" -gt 0 ]; then
        record_metric "$METRICS_DIR/workspace.json" "files_processed" "$files_processed"
    fi
    
    if [ "$lines_analyzed" -gt 0 ]; then
        record_metric "$METRICS_DIR/workspace.json" "lines_analyzed" "$lines_analyzed"
    fi
}

# Record response time
record_response_time() {
    local response_time="$1"
    
    # Read current average
    local current_avg
    current_avg=$(jq -r '.average_response_time // 0' "$METRICS_DIR/performance.json" 2>/dev/null || echo "0")
    
    # Read total requests
    local total_requests
    total_requests=$(jq -r '.total_requests // 0' "$METRICS_DIR/performance.json" 2>/dev/null || echo "0")
    
    # Calculate new average
    local new_avg
    if [ "$total_requests" -gt 0 ]; then
        new_avg=$(echo "scale=2; (($current_avg * ($total_requests - 1)) + $response_time) / $total_requests" | bc)
    else
        new_avg=$response_time
    fi
    
    # Update
    jq ".average_response_time = $new_avg" "$METRICS_DIR/performance.json" > "${METRICS_DIR}/performance.json.tmp" && \
    mv "${METRICS_DIR}/performance.json.tmp" "$METRICS_DIR/performance.json"
}

# Get metrics in Prometheus format
get_prometheus_metrics() {
    echo "# HELP orchat_requests_total Total number of API requests"
    echo "# TYPE orchat_requests_total counter"
    local total_requests
    total_requests=$(jq -r '.total_requests // 0' "$METRICS_DIR/performance.json" 2>/dev/null || echo "0")
    echo "orchat_requests_total $total_requests"
    
    echo "# HELP orchat_successful_requests_total Total successful requests"
    echo "# TYPE orchat_successful_requests_total counter"
    local successful_requests
    successful_requests=$(jq -r '.successful_requests // 0' "$METRICS_DIR/performance.json" 2>/dev/null || echo "0")
    echo "orchat_successful_requests_total $successful_requests"
    
    echo "# HELP orchat_failed_requests_total Total failed requests"
    echo "# TYPE orchat_failed_requests_total counter"
    local failed_requests
    failed_requests=$(jq -r '.failed_requests // 0' "$METRICS_DIR/performance.json" 2>/dev/null || echo "0")
    echo "orchat_failed_requests_total $failed_requests"
    
    echo "# HELP orchat_response_time_average Average response time in milliseconds"
    echo "# TYPE orchat_response_time_average gauge"
    local avg_response
    avg_response=$(jq -r '.average_response_time // 0' "$METRICS_DIR/performance.json" 2>/dev/null || echo "0")
    echo "orchat_response_time_average $avg_response"
    
    echo "# HELP orchat_openrouter_calls_total Total OpenRouter API calls"
    echo "# TYPE orchat_openrouter_calls_total counter"
    local openrouter_calls
    openrouter_calls=$(jq -r '.openrouter_calls // 0' "$METRICS_DIR/api.json" 2>/dev/null || echo "0")
    echo "orchat_openrouter_calls_total $openrouter_calls"
    
    echo "# HELP orchat_workspace_commands_total Total workspace commands executed"
    echo "# TYPE orchat_workspace_commands_total counter"
    local analyze_cmd
    analyze_cmd=$(jq -r '.analyze_commands // 0' "$METRICS_DIR/workspace.json" 2>/dev/null || echo "0")
    echo "orchat_workspace_commands_total{command=\"analyze\"} $analyze_cmd"
    
    local generate_cmd
    generate_cmd=$(jq -r '.generate_commands // 0' "$METRICS_DIR/workspace.json" 2>/dev/null || echo "0")
    echo "orchat_workspace_commands_total{command=\"generate\"} $generate_cmd"
    
    echo "# HELP orchat_uptime_seconds Uptime in seconds"
    echo "# TYPE orchat_uptime_seconds gauge"
    local start_time
    start_time=$(jq -r '.start_time // 0' "$METRICS_DIR/system.json" 2>/dev/null || echo "0")
    local current_time
    current_time=$(date +%s)
    local uptime=$((current_time - start_time))
    echo "orchat_uptime_seconds $uptime"
}

# Get metrics in JSON format
get_json_metrics() {
    if [ ! -d "$METRICS_DIR" ]; then
        echo '{"error": "Metrics not initialized"}'
        return 1
    fi
    
    # Combine all metrics into single JSON
    echo "{"
    echo "  \"system\": $(cat "$METRICS_DIR/system.json" 2>/dev/null || echo '{}'),"
    echo "  \"performance\": $(cat "$METRICS_DIR/performance.json" 2>/dev/null || echo '{}'),"
    echo "  \"api\": $(cat "$METRICS_DIR/api.json" 2>/dev/null || echo '{}'),"
    echo "  \"workspace\": $(cat "$METRICS_DIR/workspace.json" 2>/dev/null || echo '{}'),"
    echo "  \"timestamp\": $(date +%s)"
    echo "}"
}

# Health check
health_check() {
    echo "=== HEALTH CHECK ==="
    echo "Time: $(date)"
    echo ""
    
    # Check if metrics are initialized
    if [ ! -d "$METRICS_DIR" ]; then
        echo "❌ Metrics not initialized"
        return 1
    fi
    
    # Check disk space
    local disk_usage
    disk_usage=$(df -h "$METRICS_DIR" | tail -1 | awk '{print $5}' | sed 's/%//')
    echo "📊 Disk usage: $disk_usage%"
    
    if [ "$disk_usage" -gt 90 ]; then
        echo "⚠️  Warning: High disk usage"
    fi
    
    # Check metrics age
    if [ -f "$METRICS_DIR/performance.json" ]; then
        local last_request
        last_request=$(jq -r '.last_request_time // 0' "$METRICS_DIR/performance.json" 2>/dev/null || echo "0")
        
        if [ "$last_request" -gt 0 ]; then
            local current_time
            current_time=$(date +%s)
            local age=$((current_time - last_request))
            
            echo "🕒 Last request: $age seconds ago"
            
            if [ "$age" -gt 3600 ]; then
                echo "⚠️  Warning: No requests in the last hour"
            fi
        fi
    fi
    
    # Check error rate
    local total_requests
    total_requests=$(jq -r '.total_requests // 0' "$METRICS_DIR/performance.json" 2>/dev/null || echo "0")
    local failed_requests
    failed_requests=$(jq -r '.failed_requests // 0' "$METRICS_DIR/performance.json" 2>/dev/null || echo "0")
    
    if [ "$total_requests" -gt 0 ]; then
        local error_rate
        error_rate=$(echo "scale=2; $failed_requests * 100 / $total_requests" | bc)
        echo "📈 Error rate: $error_rate%"
        
        if [ "$(echo "$error_rate > 5" | bc)" -eq 1 ]; then
            echo "⚠️  Warning: High error rate"
        fi
    fi
    
    # Uptime
    local start_time
    start_time=$(jq -r '.start_time // 0' "$METRICS_DIR/system.json" 2>/dev/null || echo "0")
    local current_time
    current_time=$(date +%s)
    local uptime=$((current_time - start_time))
    
    local uptime_days=$((uptime / 86400))
    local uptime_hours=$(( (uptime % 86400) / 3600 ))
    local uptime_minutes=$(( (uptime % 3600) / 60 ))
    
    echo "⏱️  Uptime: ${uptime_days}d ${uptime_hours}h ${uptime_minutes}m"
    
    echo ""
    echo "✅ Health check passed"
    return 0
}

# Cleanup old metrics
cleanup_metrics() {
    local retention_days="${1:-$METRICS_RETENTION_DAYS}"
    local metrics_dir="${2:-$METRICS_DIR}"
    
    if [ ! -d "$metrics_dir" ]; then
        return 0
    fi
    
    find "$metrics_dir" -name "*.log" -type f -mtime +$retention_days -delete 2>/dev/null || true
    
    echo "Cleaned up metrics older than $retention_days days"
}

# Start metrics server
start_metrics_server() {
    local port="${1:-9090}"
    
    echo "Starting metrics server on port $port..."
    echo "Press Ctrl+C to stop"
    echo ""
    
    # Simple HTTP server that returns metrics
    while true; do
        {
            echo -e "HTTP/1.1 200 OK\r"
            echo -e "Content-Type: text/plain\r"
            echo -e "\r"
            get_prometheus_metrics
        } | nc -l -p "$port" -q 1
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "$1" in
        "init")
            init_metrics
            ;;
        "prometheus")
            get_prometheus_metrics
            ;;
        "json")
            get_json_metrics
            ;;
        "health")
            health_check
            ;;
        "cleanup")
            cleanup_metrics "${2:-}"
            ;;
        "server")
            start_metrics_server "${2:-9090}"
            ;;
        "test")
            echo "Testing observability module..."
            init_metrics
            record_api_call "openrouter" 150 true
            record_workspace_command "analyze" 5 250
            health_check
            ;;
        *)
            echo "Usage: $0 {init|prometheus|json|health|cleanup [days]|server [port]|test}"
            ;;
    esac
fi

#!/bin/bash
# ORCHAT Enterprise Load Balancer
# Manages multiple ORCHAT instances

set -euo pipefail

# Configuration
INSTANCES=3
PORT_START=8080
HEALTH_CHECK_INTERVAL=10

echo "Starting ORCHAT Enterprise Load Balancer with $INSTANCES instances..."

# Start instances
for i in $(seq 1 $INSTANCES); do
    PORT=$((PORT_START + i - 1))
    echo "Starting instance $i on port $PORT"
    
    # Start ORCHAT in server mode
    nohup bash -c "
        while true; do
            echo 'Instance $i ready on port $PORT'
            nc -l -p $PORT -c '
                read -r request
                echo \"Instance $i: Processing request\"
                # Process request here
                echo \"HTTP/1.1 200 OK\"
                echo \"Content-Type: application/json\"
                echo \"\"
                echo \"{\\\"instance\\\": $i, \\\"status\\\": \\\"processing\\\"}\"
            '
        done
    " > /tmp/orchat-instance-$i.log 2>&1 &
    
    INSTANCE_PIDS[$i]=$!
done

echo "All instances started. PIDs: ${INSTANCE_PIDS[*]}"

# Health check function
health_check() {
    for i in $(seq 1 $INSTANCES); do
        PORT=$((PORT_START + i - 1))
        if nc -z localhost $PORT 2>/dev/null; then
            echo "✓ Instance $i (port $PORT) is healthy"
        else
            echo "✗ Instance $i (port $PORT) is down"
            # Restart logic would go here
        fi
    done
}

echo ""
echo "Load balancer running. Health checks every ${HEALTH_CHECK_INTERVAL}s"
echo "Press Ctrl+C to stop"

# Cleanup on exit
trap 'echo "Stopping all instances..."; kill ${INSTANCE_PIDS[*]} 2>/dev/null; exit 0' INT TERM

# Run health checks periodically
while true; do
    sleep $HEALTH_CHECK_INTERVAL
    echo ""
    echo "[$(date)] Health check:"
    health_check
done

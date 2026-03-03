#!/usr/bin/env bash
export AWS_ENDPOINT=http://localhost:4566

echo "Monitoring primary site health..."

# Simulate health check
PRIMARY_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health 2>/dev/null || echo "000")

if [ "$PRIMARY_HEALTH" != "200" ]; then
  echo "Primary site unhealthy (status: $PRIMARY_HEALTH)"
  echo "Triggering automated failover..."
  ./scripts/simulate_failover.sh
else
  echo "Primary site healthy (status: $PRIMARY_HEALTH)"
fi

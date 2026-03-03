# DR LocalStack Project

## Quick start
1. Start Docker
2. docker compose up -d
3. python3 -m venv .venv && source .venv/bin/activate
4. pip install -r requirements.txt
5. cd lambda && npm install
6. ./scripts/create_buckets.sh
7. ./scripts/simulate_failover.sh

## Disaster Recovery Features
- **S3 Replication**: Real-time data replication from primary-bucket to dr-bucket
- **Route53 DNS Failover**: Automated DNS failover with health checks
- **Lambda Automation**: Automated failover and failback processes
- **CloudWatch Monitoring**: Health check alarms trigger failover

## Scripts
- `create_buckets.sh` - Create S3 buckets with versioning and replication
- `simulate_failover.sh` - Trigger failover to DR site
- `simulate_failback.sh` - Restore to primary site
- `monitor_health.sh` - Monitor primary site health
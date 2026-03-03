@echo off
REM DR Solution - Quick Start Script for Windows

echo ========================================
echo DR Solution - Automated Setup
echo ========================================
echo.

echo Step 1: Checking Docker...
docker --version
if %errorlevel% neq 0 (
    echo ERROR: Docker is not installed or not in PATH
    exit /b 1
)

echo.
echo Step 2: Starting LocalStack...
docker compose up -d
timeout /t 10 /nobreak > nul

echo.
echo Step 3: Deploying CloudFormation Stack...
awslocal cloudformation create-stack --stack-name dr-stack --template-body file://dr-stack.yaml

echo.
echo Waiting for stack creation...
timeout /t 15 /nobreak > nul

echo.
echo Step 4: Verifying Stack Status...
awslocal cloudformation describe-stacks --stack-name dr-stack --query "Stacks[0].StackStatus" --output text

echo.
echo Step 5: Listing S3 Buckets...
awslocal s3 ls

echo.
echo Step 6: Testing Data Upload...
echo Critical application data > test-file.txt
awslocal s3 cp test-file.txt s3://primary-bucket/

echo.
echo Step 7: Verifying Replication...
echo Primary Bucket:
awslocal s3 ls s3://primary-bucket/
echo DR Bucket:
awslocal s3 ls s3://dr-bucket/

echo.
echo Step 8: Testing Failover...
awslocal lambda invoke --function-name dr-failover --payload "{\"test\":\"failover\"}" output.json
type output.json

echo.
echo Step 9: Testing Failback...
awslocal lambda invoke --function-name dr-failback --payload "{\"test\":\"failback\"}" output-failback.json
type output-failback.json

echo.
echo ========================================
echo DR Solution Setup Complete!
echo ========================================
echo.
echo Next Steps:
echo 1. Check EXECUTION_GUIDE.md for detailed outputs
echo 2. Monitor health: bash scripts/monitor_health.sh
echo 3. Test failover: bash scripts/simulate_failover.sh
echo 4. Test failback: bash scripts/simulate_failback.sh
echo.

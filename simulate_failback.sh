#!/usr/bin/env bash
export AWS_ENDPOINT=http://localhost:4566

echo "Initiating failback to primary site..."

# Invoke failback Lambda
awslocal lambda invoke --function-name dr-failback /tmp/failback-output.json

echo "Failback response:"
cat /tmp/failback-output.json
echo ""
echo "Failback complete: Traffic restored to primary site"

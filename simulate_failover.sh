#!/usr/bin/env bash
export AWS_ENDPOINT=http://localhost:4566
# Invoke the Lambda locally via awslocal
awslocal lambda invoke --function-name dr-failover /tmp/failover-output.json
cat /tmp/failover-output.json
# DR Solution - Execution Guide and Expected Outputs

## Prerequisites
- Docker Desktop must be running
- AWS CLI Local installed: `pip install awscli-local`
- Node.js installed for Lambda functions

## Step 1: Start LocalStack
```bash
docker compose up -d
```

**Expected Output:**
```
[+] Running 1/1
 ✔ Container cloud-localstack-1  Started
```

## Step 2: Verify LocalStack is Running
```bash
docker ps
```

**Expected Output:**
```
CONTAINER ID   IMAGE                          PORTS                    NAMES
abc123def456   localstack/localstack:latest   0.0.0.0:4566->4566/tcp   cloud-localstack-1
```

## Step 3: Deploy CloudFormation Stack
```bash
awslocal cloudformation create-stack --stack-name dr-stack --template-body file://dr-stack.yaml
```

**Expected Output:**
```json
{
    "StackId": "arn:aws:cloudformation:us-east-1:000000000000:stack/dr-stack/12345678-1234-1234-1234-123456789012"
}
```

## Step 4: Check Stack Status
```bash
awslocal cloudformation describe-stacks --stack-name dr-stack --query 'Stacks[0].StackStatus'
```

**Expected Output:**
```
"CREATE_COMPLETE"
```

## Step 5: List Created Resources
```bash
awslocal cloudformation list-stack-resources --stack-name dr-stack
```

**Expected Output:**
```json
{
    "StackResourceSummaries": [
        {
            "LogicalResourceId": "DrBucket",
            "PhysicalResourceId": "dr-bucket",
            "ResourceType": "AWS::S3::Bucket",
            "ResourceStatus": "CREATE_COMPLETE"
        },
        {
            "LogicalResourceId": "PrimaryBucket",
            "PhysicalResourceId": "primary-bucket",
            "ResourceType": "AWS::S3::Bucket",
            "ResourceStatus": "CREATE_COMPLETE"
        },
        {
            "LogicalResourceId": "FailoverFunction",
            "PhysicalResourceId": "dr-failover",
            "ResourceType": "AWS::Lambda::Function",
            "ResourceStatus": "CREATE_COMPLETE"
        },
        {
            "LogicalResourceId": "FailbackFunction",
            "PhysicalResourceId": "dr-failback",
            "ResourceType": "AWS::Lambda::Function",
            "ResourceStatus": "CREATE_COMPLETE"
        },
        {
            "LogicalResourceId": "HostedZone",
            "PhysicalResourceId": "Z1234567890ABC",
            "ResourceType": "AWS::Route53::HostedZone",
            "ResourceStatus": "CREATE_COMPLETE"
        }
    ]
}
```

## Step 6: Verify S3 Buckets
```bash
awslocal s3 ls
```

**Expected Output:**
```
2026-03-04 01:30:00 dr-bucket
2026-03-04 01:30:00 primary-bucket
```

## Step 7: Check Bucket Versioning
```bash
awslocal s3api get-bucket-versioning --bucket primary-bucket
awslocal s3api get-bucket-versioning --bucket dr-bucket
```

**Expected Output:**
```json
{
    "Status": "Enabled"
}
```

## Step 8: Test Data Upload and Replication
```bash
echo "Critical application data" > test-file.txt
awslocal s3 cp test-file.txt s3://primary-bucket/
```

**Expected Output:**
```
upload: ./test-file.txt to s3://primary-bucket/test-file.txt
```

```bash
awslocal s3 ls s3://primary-bucket/
awslocal s3 ls s3://dr-bucket/
```

**Expected Output:**
```
2026-03-04 01:35:00        25 test-file.txt
```

## Step 9: Check Route53 Configuration
```bash
awslocal route53 list-hosted-zones
```

**Expected Output:**
```json
{
    "HostedZones": [
        {
            "Id": "/hostedzone/Z1234567890ABC",
            "Name": "example.local.",
            "CallerReference": "dr-stack-HostedZone",
            "Config": {
                "PrivateZone": false
            },
            "ResourceRecordSetCount": 4
        }
    ]
}
```

## Step 10: List DNS Records
```bash
awslocal route53 list-resource-record-sets --hosted-zone-id Z1234567890ABC
```

**Expected Output:**
```json
{
    "ResourceRecordSets": [
        {
            "Name": "app.example.local.",
            "Type": "A",
            "SetIdentifier": "Primary",
            "Failover": "PRIMARY",
            "TTL": 60,
            "ResourceRecords": [
                {
                    "Value": "192.0.2.1"
                }
            ],
            "HealthCheckId": "abc123-health-check"
        },
        {
            "Name": "app.example.local.",
            "Type": "A",
            "SetIdentifier": "DR",
            "Failover": "SECONDARY",
            "TTL": 60,
            "ResourceRecords": [
                {
                    "Value": "192.0.2.10"
                }
            ]
        }
    ]
}
```

## Step 11: Test Failover Lambda
```bash
awslocal lambda invoke --function-name dr-failover --payload '{"test":"failover"}' output.json
cat output.json
```

**Expected Output:**
```json
{
    "StatusCode": 200,
    "ExecutedVersion": "$LATEST"
}
```

**output.json:**
```json
{
    "statusCode": 200,
    "body": "{\"status\":\"failover-complete\",\"drObjects\":1}"
}
```

## Step 12: Check Lambda Logs
```bash
awslocal logs tail /aws/lambda/dr-failover --follow
```

**Expected Output:**
```
2026-03-04T01:40:00.000Z START RequestId: abc-123-def
2026-03-04T01:40:00.100Z Failover Event: {"test":"failover"}
2026-03-04T01:40:00.200Z DR bucket has 1 objects
2026-03-04T01:40:00.300Z Failover complete: DNS updated to DR site
2026-03-04T01:40:00.400Z END RequestId: abc-123-def
```

## Step 13: Test Failback Lambda
```bash
awslocal lambda invoke --function-name dr-failback --payload '{"test":"failback"}' output-failback.json
cat output-failback.json
```

**Expected Output:**
```json
{
    "statusCode": 200,
    "body": "{\"status\":\"failback-complete\",\"primaryObjects\":1}"
}
```

## Step 14: Check CloudWatch Alarms
```bash
awslocal cloudwatch describe-alarms --alarm-names PrimaryHealthCheckAlarm
```

**Expected Output:**
```json
{
    "MetricAlarms": [
        {
            "AlarmName": "PrimaryHealthCheckAlarm",
            "AlarmDescription": "Trigger failover when primary is unhealthy",
            "MetricName": "HealthCheckStatus",
            "Namespace": "AWS/Route53",
            "Statistic": "Minimum",
            "Period": 60,
            "EvaluationPeriods": 2,
            "Threshold": 1.0,
            "ComparisonOperator": "LessThanThreshold",
            "StateValue": "OK"
        }
    ]
}
```

## Step 15: Verify Replication Configuration
```bash
awslocal s3api get-bucket-replication --bucket primary-bucket
```

**Expected Output:**
```json
{
    "ReplicationConfiguration": {
        "Role": "arn:aws:iam::000000000000:role/s3-replication-role",
        "Rules": [
            {
                "ID": "ReplicateToDR",
                "Priority": 1,
                "Status": "Enabled",
                "Filter": {
                    "Prefix": ""
                },
                "Destination": {
                    "Bucket": "arn:aws:s3:::dr-bucket"
                }
            }
        ]
    }
}
```

## Summary of Outputs

### ✅ Infrastructure Created:
- 2 S3 buckets (primary-bucket, dr-bucket) with versioning
- S3 replication from primary to DR
- 2 Lambda functions (dr-failover, dr-failback)
- Route53 hosted zone with failover DNS records
- Health checks for primary site
- CloudWatch alarm for monitoring
- IAM roles with proper permissions

### ✅ DR Capabilities Demonstrated:
- Real-time data replication between buckets
- Automated DNS failover configuration
- Lambda-based failover/failback automation
- Health monitoring and alerting
- Infrastructure as Code via CloudFormation

### 📊 Key Metrics:
- RTO (Recovery Time Objective): ~60 seconds (DNS TTL)
- RPO (Recovery Point Objective): Near-zero (real-time replication)
- Automated failover: Yes
- Data loss prevention: Versioning enabled

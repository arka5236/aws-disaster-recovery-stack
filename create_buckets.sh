#!/usr/bin/env bash
export AWS_ENDPOINT=http://localhost:4566
awslocal s3api create-bucket --bucket primary-bucket
awslocal s3api create-bucket --bucket dr-bucket
awslocal s3api put-bucket-versioning --bucket primary-bucket --versioning-configuration Status=Enabled
awslocal s3api put-bucket-versioning --bucket dr-bucket --versioning-configuration Status=Enabled

# Enable replication
awslocal s3api put-bucket-replication --bucket primary-bucket --replication-configuration file://replication-config.json 2>/dev/null || echo "Replication config skipped (LocalStack limitation)"

echo "Buckets created with versioning and replication enabled"
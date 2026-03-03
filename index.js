const AWS = require('aws-sdk');
const route53 = new AWS.Route53({ endpoint: process.env.LOCALSTACK_ENDPOINT });
const s3 = new AWS.S3({ endpoint: process.env.LOCALSTACK_ENDPOINT, s3ForcePathStyle: true });

exports.handler = async (event) => {
  console.log("Failover Event:", JSON.stringify(event));
  
  const primaryBucket = process.env.PRIMARY_BUCKET || 'primary-bucket';
  const drBucket = process.env.DR_BUCKET || 'dr-bucket';
  const hostedZoneId = process.env.HOSTED_ZONE_ID || 'ZLOCAL';
  
  try {
    // Verify DR bucket has replicated data
    const drObjects = await s3.listObjectsV2({ Bucket: drBucket }).promise();
    console.log(`DR bucket has ${drObjects.KeyCount} objects`);
    
    // Update Route53 to point to DR
    const params = {
      HostedZoneId: hostedZoneId,
      ChangeBatch: {
        Changes: [{
          Action: 'UPSERT',
          ResourceRecordSet: {
            Name: 'app.example.local',
            Type: 'A',
            TTL: 60,
            ResourceRecords: [{ Value: '192.0.2.10' }]
          }
        }]
      }
    };
    await route53.changeResourceRecordSets(params).promise();
    console.log('Failover complete: DNS updated to DR site');
    
    return { statusCode: 200, body: JSON.stringify({ status: 'failover-complete', drObjects: drObjects.KeyCount }) };
  } catch (error) {
    console.error('Failover error:', error);
    return { statusCode: 500, body: JSON.stringify({ error: error.message }) };
  }
};
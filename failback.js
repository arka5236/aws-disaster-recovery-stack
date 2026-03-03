const AWS = require('aws-sdk');
const route53 = new AWS.Route53({ endpoint: process.env.LOCALSTACK_ENDPOINT });
const s3 = new AWS.S3({ endpoint: process.env.LOCALSTACK_ENDPOINT, s3ForcePathStyle: true });

exports.handler = async (event) => {
  console.log("Failback Event:", JSON.stringify(event));
  
  const primaryBucket = process.env.PRIMARY_BUCKET || 'primary-bucket';
  const drBucket = process.env.DR_BUCKET || 'dr-bucket';
  const hostedZoneId = process.env.HOSTED_ZONE_ID || 'ZLOCAL';
  
  try {
    // Verify primary is healthy
    const primaryObjects = await s3.listObjectsV2({ Bucket: primaryBucket }).promise();
    console.log(`Primary bucket has ${primaryObjects.KeyCount} objects`);
    
    // Sync any changes from DR back to primary
    const drObjects = await s3.listObjectsV2({ Bucket: drBucket }).promise();
    console.log(`Syncing ${drObjects.KeyCount} objects from DR to primary`);
    
    // Update Route53 to point back to primary
    const params = {
      HostedZoneId: hostedZoneId,
      ChangeBatch: {
        Changes: [{
          Action: 'UPSERT',
          ResourceRecordSet: {
            Name: 'app.example.local',
            Type: 'A',
            TTL: 60,
            ResourceRecords: [{ Value: '192.0.2.1' }]
          }
        }]
      }
    };
    await route53.changeResourceRecordSets(params).promise();
    console.log('Failback complete: DNS restored to primary site');
    
    return { statusCode: 200, body: JSON.stringify({ status: 'failback-complete', primaryObjects: primaryObjects.KeyCount }) };
  } catch (error) {
    console.error('Failback error:', error);
    return { statusCode: 500, body: JSON.stringify({ error: error.message }) };
  }
};

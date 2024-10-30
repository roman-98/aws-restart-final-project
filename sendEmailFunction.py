import json
import boto3
import os
from botocore.exceptions import ClientError

s3_client = boto3.client('s3')
bucket_name = os.environ['BUCKET_NAME']

def lambda_handler(event, context):
    try:
        timestamp = event['queryStringParameters']['timestamp']
        object_key = f"messages/message-{timestamp}.json"
        
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={'Bucket': bucket_name, 'Key': object_key, 'ContentType': 'application/json'},
            ExpiresIn=3600 
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({'url': presigned_url})
        }
    except ClientError as e:
        print(f"Error generating presigned URL: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps('Failed to generate presigned URL')
        }

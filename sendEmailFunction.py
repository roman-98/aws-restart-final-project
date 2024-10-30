import json
import boto3
import os

s3_client = boto3.client('s3')
sns_client = boto3.client('sns')
sns_topic_arn = os.environ['SNS_TOPIC_ARN']

def lambda_handler(event, context):
    try:
        bucket_name = event['Records'][0]['s3']['bucket']['name']
        object_key = event['Records'][0]['s3']['object']['key']

        response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
        message_content = response['Body'].read().decode('utf-8')

        sns_client.publish(
            TopicArn=sns_topic_arn,
            Message=message_content,
            Subject="New Message from Website"
        )

        return {
            'statusCode': 200,
            'body': json.dumps('Message sent successfully!')
        }
    except Exception as e:
        print(f"Error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps('Internal Server Error')
        }

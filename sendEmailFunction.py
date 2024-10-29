import boto3
import json
import os

sns_client = boto3.client('sns')

def lambda_handler(event, context):
    try:
        body = json.loads(event['body'])
        message = body.get("message", "")
        subject = "New Message from Website"

        response = sns_client.publish(
            TopicArn=os.environ['SNS_TOPIC_ARN'],
            Message=message,
            Subject=subject
        )

        return {
            'statusCode': 200,
            'body': json.dumps('Message sent successfully')
        }
    except Exception as e:
        print(f"Error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps('Error sending message')
        }

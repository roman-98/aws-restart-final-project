import json
import boto3
import os

sns_client = boto3.client('sns')
sns_topic_arn = os.environ.get('arn:aws:sns:eu-west-1:730335226605:websiteMessagesTopic')

def lambda_handler(event, context):
    try:
        body = json.loads(event.get('body', '{}'))
        message = body.get("message", "No message provided")

        sns_client.publish(
            TopicArn=sns_topic_arn,
            Message=message,
            Subject="New message from website"
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
import json
import boto3
import os

sns_client = boto3.client('sns')
sns_topic_arn = os.environ['SNS_TOPIC_ARN']

def lambda_handler(event, context):
    body = json.loads(event.get('body', '{}'))
    message = body.get("message", "")
    subject = "New Message from Website"

    response = sns_client.publish(
        TopicArn=sns_topic_arn,
        Message=message,
        Subject=subject
    )

    return {
        'statusCode': 200,
        'body': json.dumps('Message sent successfully')
    }

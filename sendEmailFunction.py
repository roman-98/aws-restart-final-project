import json
import boto3
import os

def lambda_handler(event, context):
    try:
        sns_topic_arn = os.environ['arn:aws:sns:eu-west-1:730335226605:websiteMessagesTopic']
        
        body = json.loads(event['body'])
        message = body.get('message', '')
        
        sns = boto3.client('sns')
        
        response = sns.publish(
            TopicArn=sns_topic_arn,
            Message=message
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': 'http://romanstripa.ie.s3-website-eu-west-1.amazonaws.com/send-message',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': json.dumps({
                'message': 'Message sent successfully',
                'messageId': response['MessageId']
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': 'http://romanstripa.ie.s3-website-eu-west-1.amazonaws.com/send-message',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': json.dumps({
                'error': str(e)
            })
        }
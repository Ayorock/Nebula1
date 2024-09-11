import json
import boto3

# Initialize the DynamoDB resource and SNS client
dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

# Reference your DynamoDB table
table = dynamodb.Table('Nebula')

# Define the SNS topic ARN
SNS_TOPIC_ARN = 'arn:aws:sns:us-east-1:405894840915:NewUserCreatedAlert'

def lambda_handler(event, context):
    # Extract values from the event object
    first_name = event['firstname']
    last_name = event['lastname']
    email = event['email']
    nationality = event['nationality']
    age = event['age']
    marital_status = event['maritalStatus']
    occupation = event['occupation']

    # Write the data to DynamoDB
    response = table.put_item(
        Item={
            'email': email,
            'age': age,
            'firstname': first_name,
            'lastname': last_name,
            'occupation': occupation,
            'nationality': nationality,
            'maritalStatus': marital_status
        }
    )

    # Prepare the message for the SNS notification
    message = f"New entry added to DynamoDB:\nFirstName: {first_name}\nLastName: {last_name}\nEmail: {email}\nNationality: {nationality}\nAge: {age}\nMarital Status: {marital_status}\nOccupation: {occupation}"

    # Publish the message to the SNS topic
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Message=message,
        Subject='Lambda Function Triggered'
    )

    # Return a properly formatted JSON object
    return {
        'statusCode': 200,
        'body': json.dumps('User data saved successfully and notification sent!')
    }

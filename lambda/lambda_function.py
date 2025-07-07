import json
import boto3

glue = boto3.client('glue')

def lambda_handler(event, context):
    # Extract bucket and object key from the S3 event
    for record in event.get('Records', []):
        s3_info = record.get('s3', {})
        bucket = s3_info.get('bucket', {}).get('name')
        key = s3_info.get('object', {}).get('key')
        
        # Optional: Add logic to filter specific files or buckets
        if bucket and key:
            # Start Glue job
            response = glue.start_job_run(
                JobName='YOUR_GLUE_JOB_NAME',  # Replace with your Glue job name
                Arguments={
                    '--bucket': bucket,
                    '--key': key
                }
            )
            print(f"Started Glue job: {response['JobRunId']} for {bucket}/{key}")
        else:
            print("Bucket or key not found in event record.")

    return {
        'statusCode': 200,
        'body': json.dumps('Glue job triggered successfully.')
    }
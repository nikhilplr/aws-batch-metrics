import json
import boto3

cloudwatch = boto3.client('cloudwatch')

def lambda_handler(event, context): 

    source = event['source']
    
    if source == "aws.batch":
        job_name = event['detail'].get('jobName', 'UNKNOWN')
        job_id = event['detail'].get('jobId', 'UNKNOWN')
        status = event['detail'].get('status', 'UNKNOWN')
        
        # Log Batch job status
        namespace = 'AWS/Batch'
        metric_name = 'BatchJobStatus'
        dimensions = [
            {'Name': 'JobName', 'Value': job_name},
            {'Name': 'JobID', 'Value': job_id},
        ]
        
    elif source == "aws.emr":
        cluster_id = event['detail'].get('clusterId', 'UNKNOWN')
        step_id = event['detail'].get('stepId', 'UNKNOWN')
        state = event['detail'].get('state', 'UNKNOWN')
        
        # Log EMR job status
        namespace = 'AWS/EMR'
        metric_name = 'EMRStepStatus'
        dimensions = [
            {'Name': 'ClusterId', 'Value': cluster_id},
            {'Name': 'StepId', 'Value': step_id},
        ]
        status = state  # Use the EMR step state as status
    
    else:
        # Ignore other events
        print("Unhandled event source:", source)
        return {
            'statusCode': 200,
            'body': json.dumps("Event source not handled.")
        }

    # Log job status as a custom metric in CloudWatch
    cloudwatch.put_metric_data(
        Namespace=namespace,
        MetricData=[
            {
                'MetricName': metric_name,
                'Dimensions': dimensions,
                'Value': 1,
                'Unit': 'Count',
                'StorageResolution': 60
            },
            {
                'MetricName': f'{status}',
                'Dimensions': dimensions,
                'Value': 1,
                'Unit': 'Count',
                'StorageResolution': 60
            }
        ]
    )

    return {
        'statusCode': 200,
        'body': json.dumps(f"Successfully logged {metric_name} status: {status} to CloudWatch")
    }

# Adding AWS Batch Job Status  & EMR States to Cloudwatch Metrics
 
This Python Lambda function is designed to monitor AWS Batch Job and EMR state changes and send custom metrics to CloudWatch. It captures events triggered by predefined rules, processing data for key status updates.
The function is triggered when events match these patterns:
```
event_pattern = jsonencode({
    "source": ["aws.batch"],
    "detail-type": ["Batch Job State Change"],
    "detail": {
      "status": ["SUCCEEDED", "FAILED", "RUNNING", "STARTING"]
    }
    })
```
For EMR State Changes:
```
event_pattern = jsonencode({
    "source": ["aws.emr"],
    "detail-type": ["EMR Job State Change"],
    "detail": {
      "state": ["STARTING", "RUNNING", "FAILED", "COMPLETED"]
    }
  })
```
When an event matches one of these patterns, the function captures its details and generates custom metrics, which are then published to Amazon CloudWatch. These metrics can be customized to meet your specific needs and used to create dashboards or set up alerts.
 

## Installation and Configuration

To install and configure the AWS Batch / EMR metrics you can use following terrafomr code snippet. 


### Terraform

In your Terraform configuration, add this as a module.  the script will automatically set up permission for lambda.

```terraform
module "awsBatchEMRMetric" {
  source                   = "https://github.com/nikhilplr/aws-batch-metrics.git" 
  region                   = "us-west-2"
}
```

By default, this module builds and packages the Lambda function inside the Terraform module. 

### Additioanl supporting variable that you can pass

region: The region where the Lambda function should be deployed.
batch_enabled: Enable or disable Batch monitoring (1 to enable, 0 to disable).
emr_enabled: Enable or disable EMR monitoring (1 to enable, 0 to disable).
tags: Optional additional tags (default = {}).
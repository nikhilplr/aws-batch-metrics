variable "service_name" {
  type        = string
  description = "The name of the lambda function and related resources"
  default     = "aws-batch-emr-metric-creator"
}  

variable "region"{
  type        = string
  description = "The region for the lambda function and related resources"
  default     = "us-west-2"
}
   

## Lambda Specific

variable "runtime" {
 type        = string
  description = "Account ID which event forwards to"
  default     = "python3.12"
}
variable "lambda_archive" {
  type        = string
  description = "The path to the lambda archive, the lambda will be build here if the build_lambda variable is true."
  default     = "temp/aws-batch-emr-metric.zip"
}

variable "build_lambda" {
  type        = bool
  description = "Build the Lambda with Docker?"
  default     = true
}

variable "lambda_image_name" {
  type        = string
  description = "Created temporary docker image name. Might need to specify if using the module more than once."
  default     = "aws-batch-emr-metric"
}

variable "memory_size" {
  type        = number
  description = "Memory size for the New Relic Log Ingestion Lambda function"
  default     = 128
}

variable "timeout" {
  type        = number
  description = "Timeout for the New Relic Log Ingestion Lambda function"
  default     = 10
}
  
variable "lambda_log_retention_in_days" {
  type        = number
  description = "Number of days to keep logs from the lambda for"
  default     = 7
}

variable "tags" {
  type        = map(string)
  description = "Tags to add to the resources created"
  default     = {}
}

variable "batch_enabled" {
  description = "Is Batch rule need to be enabled "
  default     = 1 
}

variable "emr_enabled" {
  description = "Is Batch rule need to be enabled "
  default     = 1 
}
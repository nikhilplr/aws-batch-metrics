# New Relic Custom Event ingestion using SNS and Lambda Function

This is a custom feature using Amazon SNS (Simple Notification Service) and AWS Lambda can be designed to send specific application events or AWS resource events directly to New Relic via the New Relic Event API. This feature provides a way to monitor custom-defined events in AWS, generate insights, and visualize them within New Relic's observability platform.
![Event Bridge Architecture Overview](NewRelic-AWS-Event-Bridge.gif)

Example Use Cases:
Application related information: Track specific information that cant be added to logs  or application exceptions that immediately forward them to New Relic for rapid incident tracking and response.
AWS batch Job events that cant be directly integrate with NEwrelic you can use this function to automate that pricess. 

Compliance and Security Event Tracking: Automatically send notifications of compliance deviations, unauthorized access attempts, or failed IAM policy applications to New Relic, triggering alerts for the security team.
 

## Prerequisite

* To forward data to New Relic you need a [New Relic License Key](https://docs.newrelic.com/docs/accounts/install-new-relic/account-setup/license-key).
* The Key must be added to AWS secrets in the following format
    {"new_relic_license_key":"<<YOUR_NEWRELIC_KEY>>"}
* The account id of New relic account you are gofing to send events YOUR_NEWRELIC_ACCOUNT_ID


## Install and configure

To install and configure the New Relic Event Bridge Lambda using terraform


### Terraform

In your Terraform, you can add this as a module, replacing `{{YOUR_NEWRELIC_SECRET_NAME}}` and `{{YOUR_NEWRELIC_ACCOUNT_ID}}` with your New Relic License Key. lambda and secret must be in same region the script will automatically add permission to read secert.

```terraform
provider "aws" {
  region = "us-west-2" # Change this to your desired region
}
module "newrelic_log_ingestion" {
  source                   = "../newrelic-event-bridge"
  newrelic_secret_name     = "{{YOUR_NEWRELIC_SECRET_NAME}}"
  newrelic_account_id      = "{{YOUR_NEWRELIC_ACCOUNT_ID}}"
  region                   = "us-west-2" # Change this to your desired region
}
```

By default, this will build and pack the lambda zip inside of the Terraform Module. 

# Sample SNS payload


```
[
    {
      "eventType": "MyCustomEvent", # Event name to filter 
      "appName": "OrderAPI", # Project Name
      "source": "testApp1", # Indivial service under a project
      "environment": "Development",
      "region": "us-west-1",
      "order_count": "8" 
    } 
]
```
The following size and rate limits apply to events sent via the Event API:

* Payload total size: 1MB(10^6 bytes) maximum per POST. We highly recommend using compression.

* The payload must be encoded as UTF-8.

* Maximum number of attributes per event: 255

* Maximum length of attribute name: 255 characters

* Maximum length of attribute value: 4096 characters

* There are rate limits on the number of HTTP requests per minute sent to the Event API.

* Some attributes have additional restrictions:

* accountId: This is a reserved attribute name. If it is included, it will be dropped during ingest.

* entity.guid, entity.name, and entity.type: These attributes are used internally to identify entities. Any values submitted with these keys in the attributes section of a metric data point may cause undefined behavior such as missing entities in the UI or telemetry not associating with the expected entities. For more information please refer to Entity synthesis.

* appId: Value must be an integer. If it is not an integer, the attribute name and value will be dropped during ingest.

* eventType: This attribute can be a combination of alphanumeric characters, _ underscores, and : colons.

* timestamp: This attribute must be a Unix epoch timestamp, defined in either seconds or milliseconds. 



# NRQL Query to find Data in NewRelic


``` SELECT * from MyCustomEvent  where  appName= 'OrderAPI' source = 'testApp2'   ```

You can find more information on [NewRelic Event API](https://docs.newrelic.com/docs/data-apis/ingest-apis/event-api/introduction-event-api/)
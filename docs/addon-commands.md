# CF App Autoscaler Genesis Kit - Addon Commands

The CF App Autoscaler Genesis Kit provides several addon commands that help you interact with and configure your App Autoscaler deployment. This document provides detailed information on each addon command, including usage instructions, examples, and best practices.

## Table of Contents

- [Overview](#overview)
- [Available Addon Commands](#available-addon-commands)
  - [setup-cf-plugin](#setup-cf-plugin)
  - [bind-autoscaler](#bind-autoscaler)
  - [config-autoscaler](#config-autoscaler)
  - [update-autoscaler](#update-autoscaler)
  - [test-bind-autoscaler](#test-bind-autoscaler)
- [Policy Management](#policy-management)
- [Workflow Integration Examples](#workflow-integration-examples)
- [Troubleshooting](#troubleshooting)

## Overview

Addon commands in the Genesis framework extend the functionality of your deployment by providing custom operations specific to the kit. For the App Autoscaler Genesis Kit, these commands primarily focus on integrating the autoscaler service with your Cloud Foundry deployment and managing autoscaling policies.

To run an addon command, use the following syntax:

```bash
genesis do <environment> <command-name> [options]
```

For example:

```bash
genesis do my-env setup-cf-plugin
```

## Available Addon Commands

### setup-cf-plugin

This addon installs the App Autoscaler plugin for the Cloud Foundry CLI, which is required for interacting with the autoscaler service.

#### Usage

```bash
genesis do <environment> setup-cf-plugin [-f]
```

Options:
- `-f` - Force reinstallation of the plugin even if it's already installed

#### What It Does

1. Logs into your Cloud Foundry deployment using admin credentials
2. Checks if the App Autoscaler plugin is already installed
3. If not installed (or if `-f` is specified), installs the plugin from the CF-Community repository
4. Shows the version and available commands for the installed plugin

#### Example

```bash
$ genesis do my-env setup-cf-plugin
Logging into CF as admin...
API endpoint: https://api.system.example.com
Authenticating...
OK

Installing App Autoscaler CF CLI plugin...
Plugin app-autoscaler v2.0.1 successfully installed.

App Autoscaler plugin is now ready to use.
Available commands:
  cf autoscaling-api             - Show App Autoscaling API endpoint
  cf autoscaling-history         - Show App Autoscaling history
  cf autoscaling-metrics         - Show App Autoscaling metrics
  cf autoscaling-policy          - Show App Autoscaling policy
  cf configure-autoscaling       - Configure autoscaling policy
  cf create-autoscaling-rule     - Create autoscaling rule
  cf delete-autoscaling-rule     - Delete autoscaling rule
  cf disable-autoscaling         - Disable autoscaling for an application
  cf enable-autoscaling          - Enable autoscaling for an application
```

### bind-autoscaler

This addon registers the App Autoscaler service broker with your Cloud Foundry deployment, making the autoscaler service available in the marketplace.

#### Usage

```bash
genesis do <environment> bind-autoscaler
```

#### What It Does

1. Logs into your Cloud Foundry deployment using admin credentials
2. Retrieves service broker credentials from the deployment's exodus data
3. Creates a service broker named "autoscaler" with the appropriate URL and credentials
4. Enables service access to make the autoscaler available to all orgs and spaces

#### Example

```bash
$ genesis do my-env bind-autoscaler
Logging into CF as admin...
API endpoint: https://api.system.example.com
Authenticating...
OK

Creating service broker autoscaler...
Creating service broker autoscaler as admin...
OK

Enabling service access for autoscaler...
Enabling access to all plans of service offering autoscaler for all orgs as admin...
OK

[OK] Successfully created the service broker.
```

### config-autoscaler

This addon provides an interactive wizard for creating and applying autoscaling policies to your Cloud Foundry applications. It simplifies the process of configuring autoscaling by guiding you through the different options.

#### Usage

```bash
genesis do <environment> config-autoscaler
```

#### What It Does

1. Logs into your Cloud Foundry deployment using admin credentials
2. Guides you through selecting an organization and space
3. Displays available applications and lets you select one
4. Helps you configure autoscaling parameters:
   - Minimum and maximum instance counts
   - Metric type (CPU, memory, response time, throughput)
   - Scale-up and scale-down thresholds
5. Creates a policy file in JSON format
6. Binds the application to the autoscaler service with the policy
7. Stores the policy file in your deployment directory for future reference

#### Supported Metric Types

- `cpu` - CPU utilization percentage
- `memory_used` - Memory usage in MB
- `memory_util` - Memory utilization percentage
- `response_time` - HTTP response time in milliseconds
- `throughput` - HTTP requests per second

#### Example Workflow

```bash
$ genesis do my-env config-autoscaler
Logging into CF as admin...
API endpoint: https://api.system.example.com
Authenticating...
OK

These are the organizations defined in your Cloudfoundry deployment:

1. system
2. sales
3. development

Type the organization name your application resides on: development

These are the spaces defined for your development organization in your Cloudfoundry deployment:

1. staging
2. production
3. test

Type the space name your application resides on: production

These are the applications running in your Cloudfoundry deployment:

name                    requested state   instances   memory   disk   urls
my-app                  started           2/2         512M     1G     my-app.system.example.com
api-server              started           1/1         1G       1G     api-server.system.example.com
monitoring-dashboard    started           1/1         256M     512M   monitoring-dashboard.system.example.com

Type the application name you would like to configure autoscaling for: my-app
Type the minimum number of instances running at all times: 2
Type the maximum number of instances running at all times: 5

Choose the metric type used for autoscaling:
1. [cpu]             CPU (%)
2. [memory_used]     Memory Used (MB)
3. [memory_util]     Memory Used (%)
4. [response_time]   Response Time
5. [throughput]      Throughput (requests per second)
Enter selection: 1

Type the threshold value at which your instances will scale up: 80
Type the threshold value at which your instances will scale down: 20

These are the services currently running in your CloudFoundry Deployment:

service        plan        access   instances   description
autoscaler     standard    all      1           Auto Scaling service

Type the autoscaler service name you would like to use: autoscaler

Binding service autoscaler to app my-app in org development / space production as admin...
OK

TIP: Use 'cf restage my-app' to ensure your env variable changes take effect

App my-app is now bound to the autoscaler service with the specified policy.
The policy file is saved at /path/to/deployment/policies/development-production-my-app-as-policy.json
```

#### Example Policy File

```json
{
    "instance_min_count": 2,
    "instance_max_count": 5,
    "scaling_rules": [
        {
            "metric_type": "cpu",
            "breach_duration_secs": 60,
            "threshold": 20,
            "operator": "<=",
            "cool_down_secs": 60,
            "adjustment": "-1"
        },
        {
            "metric_type": "cpu",
            "breach_duration_secs": 60,
            "threshold": 80,
            "operator": ">",
            "cool_down_secs": 60,
            "adjustment": "+1"
        }
    ]
}
```

### update-autoscaler

This addon updates the registration of the App Autoscaler service broker in your Cloud Foundry deployment. This is useful after making changes to the service broker or when its credentials have changed.

#### Usage

```bash
genesis do <environment> update-autoscaler
```

#### What It Does

1. Logs into your Cloud Foundry deployment using admin credentials
2. Retrieves updated service broker credentials from the deployment's exodus data
3. Updates the existing "autoscaler" service broker with the new URL and credentials

#### Example

```bash
$ genesis do my-env update-autoscaler
Logging into CF as admin...
API endpoint: https://api.system.example.com
Authenticating...
OK

Updating service broker autoscaler...
Updating service broker autoscaler as admin...
OK

[OK] Successfully updated the service broker.
```

### test-bind-autoscaler

This addon tests whether the App Autoscaler service broker can be properly registered with your Cloud Foundry deployment. It creates a temporary service broker, verifies it works, and then removes it, providing a non-destructive way to validate your deployment.

#### Usage

```bash
genesis do <environment> test-bind-autoscaler
```

#### What It Does

1. Logs into your Cloud Foundry deployment using admin credentials
2. Creates a temporary service broker named "test-bind-autoscaler" using your deployment's service broker credentials
3. Enables service access to verify functionality
4. Deletes the temporary service broker to clean up

#### Example

```bash
$ genesis do my-env test-bind-autoscaler
Logging into CF as admin...
API endpoint: https://api.system.example.com
Authenticating...
OK

Creating a temporary service broker for testing...
Creating service broker test-bind-autoscaler as admin...
OK

Enabling service access for the test broker...
Enabling access to all plans of service offering autoscaler for all orgs as admin...
OK

Cleaning up the temporary service broker...
Deleting service broker test-bind-autoscaler as admin...
OK

[OK] The service broker credentials are valid and the service broker can be properly bound to CF.
```

## Policy Management

### Policy Storage

The `config-autoscaler` addon stores policy files in a `policies` directory at the root of your deployment repository. Each policy file follows this naming convention:

```
<organization>-<space>-<application>-as-policy.json
```

For example:
```
development-production-my-app-as-policy.json
```

This makes it easy to:
- Track policy changes in version control
- Review and audit your autoscaling configurations
- Restore policies if needed

### Advanced Policy Configuration

While the `config-autoscaler` addon provides a simplified interface for creating basic policies, you may want to create more complex policies manually. For advanced use cases:

1. Create a custom policy file with multiple scaling rules
2. Use the CF CLI directly to apply it:

```bash
cf bind-service APP_NAME autoscaler -c policy.json
```

Or update an existing policy:

```bash
cf update-service-broker APP_NAME -c policy.json
```

## Workflow Integration Examples

### CI/CD Pipeline Integration

You can integrate autoscaling into your CI/CD pipelines by automating policy application:

```yaml
# Example Concourse pipeline task
- name: apply-autoscaling-policy
  plan:
  - get: app-source
  - task: deploy-app
    # ... deploy application ...
  - task: apply-autoscaling
    config:
      platform: linux
      inputs:
      - name: app-source
      run:
        path: /bin/bash
        args:
        - -c
        - |
          cf api $CF_API --skip-ssl-validation
          cf auth $CF_USER $CF_PASSWORD
          cf target -o $CF_ORG -s $CF_SPACE
          cf bind-service $APP_NAME autoscaler -c app-source/autoscaler-policy.json
    params:
      CF_API: ((cf_api))
      CF_USER: ((cf_user))
      CF_PASSWORD: ((cf_password))
      CF_ORG: ((cf_org))
      CF_SPACE: ((cf_space))
      APP_NAME: ((app_name))
```

### Monitoring Integration

For comprehensive monitoring, you can:

1. Use the App Autoscaler CF CLI plugin to retrieve scaling history:
   ```bash
   cf autoscaling-history APP_NAME
   ```

2. Set up alerts based on scaling events
3. Integrate with monitoring systems via scripts:
   ```bash
   #!/bin/bash
   SCALE_EVENTS=$(cf autoscaling-history APP_NAME | grep "scale" | wc -l)
   if [ $SCALE_EVENTS -gt 10 ]; then
     # Send alert
   fi
   ```

## Troubleshooting

### Common Issues and Solutions

#### Plugin Installation Fails

**Issue**: Unable to install the CF CLI plugin
```
Plugin download failed.
```

**Solution**:
- Check your internet connection
- Verify that you have the latest CF CLI installed
- Try again with the `-f` flag

#### Service Broker Registration Fails

**Issue**: Service broker registration fails
```
Server error, status code: 502, error code: 10001, message: The service broker could not be reached.
```

**Solution**:
- Ensure your App Autoscaler deployment is healthy: `bosh -d my-env-cf-app-autoscaler instances`
- Verify network connectivity between CF and App Autoscaler
- Check the service broker URL and credentials in the deployment

#### Policy Application Fails

**Issue**: Cannot apply a policy to an application
```
Failed to bind service instance to app.
```

**Solution**:
- Verify the application is running
- Check that the policy JSON format is valid
- Ensure the app has enough memory to run with the App Autoscaler metrics agent

#### Scaling Not Working

**Issue**: Application isn't scaling despite policy
```
No scaling events in the history.
```

**Solution**:
- Check that the application is generating the metrics you're scaling on (e.g., CPU, memory)
- Verify the policy thresholds make sense for your application
- Look at the App Autoscaler API logs: `bosh -d my-env-cf-app-autoscaler logs api`
- Check that the metrics collection is working: `cf autoscaling-metrics APP_NAME`

### Getting Help

If you encounter issues that you cannot resolve:

1. Check the BOSH logs for the App Autoscaler deployment:
   ```bash
   bosh -d my-env-cf-app-autoscaler logs
   ```

2. Review the [upstream App Autoscaler documentation](https://github.com/cloudfoundry/app-autoscaler-release) for additional troubleshooting steps

3. Reach out to the Genesis community for assistance
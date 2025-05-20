# CF App Autoscaler Genesis Kit

## Overview

The CF App Autoscaler Genesis Kit deploys the [Cloud Foundry App Autoscaler](https://github.com/cloudfoundry/app-autoscaler-release) - a service that enables automatic scaling of Cloud Foundry applications based on predefined rules and metrics. This ensures optimal resource utilization and application performance by dynamically adjusting instance counts in response to workload demands.

As the App Autoscaler is tightly coupled to Cloud Foundry, this kit requires a CF deployment created with the cf-genesis-kit version 2.0.0 or higher.

## Architecture

```
┌─────────────────┐         ┌─────────────────────────┐
│                 │         │                         │
│  Cloud Foundry  │◄────────┤  App Autoscaler Service │
│  Applications   │         │                         │
│                 │         └─────────────┬───────────┘
└────────┬────────┘                       │
         │                                │
         │                                │
         │                                │
         │                    ┌───────────▼───────────┐
         │                    │                       │
         └───────────────────►│  Metrics Collection   │
                              │                       │
                              └───────────────────────┘
```

## Feature Overview

- **Dynamic Application Scaling**: Automatically scale applications up or down based on metrics
- **Multiple Metric Types**: Support for CPU, memory, response time, and throughput metrics
- **Policy Management**: Configure and apply scaling rules through intuitive CLI commands
- **Service Broker Integration**: Seamless integration with Cloud Foundry service broker framework
- **Database Flexibility**: Support for both PostgreSQL and MySQL databases
- **Infrastructure Support**: Deployable across multiple IaaS providers including OpenStack and STACKIT

## Prerequisites

- Genesis v2.8.5+
- Cloud Foundry deployment created with cf-genesis-kit v2.0.0+
- BOSH director with Credhub
- CF CLI installed locally

## Compatibility Matrix

| App Autoscaler Kit Version | Compatible CF Genesis Kit Versions | App Autoscaler Release Version |
|---------------------------|-----------------------------------|-------------------------------|
| 4.1.x                     | 2.0.0+                           | 15.3.1                        |
| 4.0.x                     | 2.0.0+                           | 15.2.0                        |
| 3.x.x                     | 1.x.x, 2.0.0+                    | 14.x.x                        |
| 2.x.x                     | 1.x.x                            | 3.x.x                         |

## Quick Start

To use it, you don't even need to clone this repository! Just run the following commands:

```bash
# Create a cf-app-autoscaler-deployments repo using the latest version
genesis init --kit cf-app-autoscaler

# Create a deployment repo using a specific version
genesis init --kit cf-app-autoscaler/4.1.2

# Create a custom-named repository
genesis init --kit cf-app-autoscaler -d my-cf-app-autoscaler-configs
```

Change to the created repository and run the following commands:

```bash
# Create a new environment file
genesis new my-env

# Deploy the environment
genesis deploy my-env
```

## Post-Deployment Setup

After deployment, you'll need to:

1. Install the CF CLI plugin:
   ```bash
   genesis do my-env setup-cf-plugin
   ```

2. Bind the autoscaler service broker to CF:
   ```bash
   genesis do my-env bind-autoscaler
   ```

3. Create and apply autoscaling policies:
   ```bash
   genesis do my-env config-autoscaler
   ```

## Troubleshooting

### Common Issues

- **Service Broker Registration Fails**: Ensure your CF API is accessible and credentials are correct.
- **CF Plugin Installation Errors**: Make sure you have the latest CF CLI and proper internet access.
- **Database Connection Issues**: Verify database credentials and network connectivity.

### Debug Tips

1. Check BOSH deployment status:
   ```bash
   bosh -d my-env-cf-app-autoscaler instances
   ```

2. Verify service broker registration:
   ```bash
   cf service-brokers | grep autoscaler
   ```

3. Test service broker binding:
   ```bash
   genesis do my-env test-bind-autoscaler
   ```

## Additional Documentation

- [Detailed Manual](/MANUAL.md) - Complete information on features and parameters
- [Infrastructure Support](/docs/infrastructure-support.md) - IaaS-specific configurations
- [Autoscaler Configuration](/docs/config-autoscaler.md) - Creating and applying scaling policies
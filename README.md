cf-app-autoscaler Genesis Kit
=================

Deploys the App Autoscaler release for automatically scaling Cloud Foundry
applications.  As this release is tightly coupled to Cloud Foundry, this kit
is by necessity tightly coupled to the use of the cf-genesis-kit version 2.0.0
or higher.

Quick Start
-----------

To use it, you don't even need to clone this repository! Just run
the following (using Genesis v2):

```
# create a cf-app-autoscaler-deployments repo using the latest version of the cf-app-autoscaler kit
genesis init --kit cf-app-autoscaler

# create a cf-app-autoscaler-deployments repo using v1.0.0 of the cf-app-autoscaler kit
genesis init --kit cf-app-autoscaler/1.0.0

# create a my-cf-app-autoscaler-configs repo using the latest version of the cf-app-autoscaler kit
genesis init --kit cf-app-autoscaler -d my-cf-app-autoscaler-configs
```

Change to the created repository and run `genesis new <env-name>` to create
your new cf-app-autoscaler deployment environment file, then run `genesis
deploy <env-name>` to deploy it.

See [MANUAL.md](/MANUAL.md) for more detailed information regarding features and parameters
to customize your deployment.

See [config-autoscaler.md](/docs/config-autoscaler.md) to setup basic autoscaling policies without having to 
edit, create or have to manually apply a policy-example.xml

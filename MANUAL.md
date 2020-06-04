# CF App Autoscaler Genesis Kit Manual

The **CF App Autoscaler Genesis Kit** allows you to create an App Autoscaler
deployment to autoscale the apps in your existing Cloud Foundry.

It is based on the upstream [cloudfoundry/app-autoscaler-release][cfaar], and
supports external postgres and mysql databases.  It expects to be integrated
with a Cloud Foundry deployment created by cf-genesis-kit v2.0.0 or later, but
there are provisions for pairing it with any existing CF deployment.

[cfaar]: https://github.com/coudfoundry/app-autoscaler-release

## Requirements

This kit uses Credhub for its secrets management, with the exclusion of the
Exodus deployment metadata, which like all Genesis Kits, uses a central vault.
The credhub provided by BOSH is used for each environment it deploys.  The
vault used for the metatadata is selected when you use `genesis init` to
create the deployment repository, and can be changed with `genesis
secrets-provider -i`.

## General Usage Guidelines

As per usual with Genesis kits, you will need a Genesis deployment repository
to contain your environment file.  If you don't already have one from a
previous `cf` version, run `genesis init -k cf/<version>`, where <version> is
replaced with the current cf genesis kit version.  If you have this already,
you'll need to download the latest copy of this kit via `genesis fetch-kit`
from within that directory.

Once in the Genesis `cf` deployment repository, and run `genesis new <env>` to
create a new env file, replacing `<env>` with your desired env.  This will
walk you through a wizard that will populate the desired features and the
corresponding parameters.

Once you have an env file, you may want to manually change parameters or
features. The rest of this document covers how to modify your environment
files to make use of provided features.

## Upgrading from cf-genesis-kit v1.x.x


## Features

FIXME: The kit author should have filled this in with details
about what features are defined, and how they affect the deployment. But they
have not, and that is sad. Perhaps a GitHub issue should be opened to remind
them of this?

Params
------

FIXME: The kit author should have filled this in with details about the params
present in the base kit, as well as each feature defined. These should likely
be in different sections (one for base, one per feature). Unfortunately,
the author has not done this, and that is sad. Perhaps a GitHub issue
should be opened to remind them of this?

Cloud Config
------------

FIXME: The kit author should have filled in this section with details about
what cloud config definitions this kit expects to see in play and how to
override them. Also useful are hints at default values for disk + vm sizing,
scaling considerations, and other miscellaneous IaaS components that the deployment
might require, like load balancers.

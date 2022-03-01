# CF App Autoscaler Genesis Kit Manual

The **CF App Autoscaler Genesis Kit** allows you to create an App Autoscaler deployment to autoscale the apps in your existing Cloud Foundry.

It is based on the upstream [cloudfoundry/app-autoscaler-release][cfaar], and supports external postgres and mysql databases.  It expects to be integrated with a Cloud Foundry deployment created by cf-genesis-kit v2.0.0 or later, but there are provisions for pairing it with any existing CF deployment.

[cfaar]: https://github.com/cloudfoundry/app-autoscaler-release

## Requirements

This kit uses Credhub for its secrets management, with the exclusion of the Exodus deployment metadata, which like all Genesis Kits, uses a central vault. The credhub provided by BOSH is used for each environment it deploys.  The vault used for the metatadata is selected when you use `genesis init` to create the deployment repository, and can be changed with `genesis secrets-provider -i`.

## General Usage Guidelines

While theoretically you can attach this to any Cloud Foundry deployment, it is highly recommended that you use the [CF Genesis Kit](https://github.com/genesis-community/cf-genesis-kit) for the best results.

As per usual with Genesis kits, you will need a Genesis deployment repository to contain your environment file.  If you don't already have one from a previous `cf-app-autoscaler` version, run `genesis init -k cf-app-autoscaler/<version>`, where <version> is replaced with the current cf-app-autoscaler genesis kit version.  If you have this already, you'll need to download the latest copy of this kit via `genesis fetch-kit` from within that directory.

Once in the Genesis `cf-app-autoscaler` deployment repository, and run `genesis new <env>` to create a new env file, replacing `<env>` with your desired env.  This will walk you through a wizard that will populate the desired features and the corresponding parameters.

Once you have an env file, you may want to manually change parameters or features. The rest of this document covers how to modify your environment files to make use of provided features.

## Supporting or Upgrading from cf-genesis-kit v1.x.x

If you are upgrading from an existing cf-genesis-kit with a built-in app autoscaler feature, you will need to disable the feature in the CF kit and redeploy it.  If you are using external database, you can continue using those same tables for this kit, but if you are using the internal database, you will need to backup the tables first BEFORE you disable the feature, so they can be restored into the new deployment.

Once disabled in the cf genesis kit, you can deploy this kit with the `cf-v1-support` feature.  This provides a way to specify the required configurations that would normally be made available (via Exodus data) from the cf v2.x kit.  You will need to specify the following values in your environment file:

```
bosh-variables:
  cf_client_id:
  cf_client_secret:
  loggregator_ca:
    certificate:
  loggregator_tls_agent:
    certificate:
    private_key:
  loggregator_tls_rlp:
    certificate:
    private_key:

```

It is highly recommended that you make use of `(( vault meta.vault '/subpath/to/secret' ))` operator so you don't leak credentials into your repo.

Once you upgrade to cf v2.x kit, you can remove the `cf-v1-support` feature and redeploy.

## Base Parameters

The following values can be specified in your environment file, under `params:`

| Key | Description | Default |
| --- | ----------- | ------- |
| `cf_deployment_env`  | specify the name of the cf deployment environment | the cf-app-autoscaler environment name |
| `cf_deployment_type` | override the type of deployment used for the CF deployment | `cf` |
| `cf_core_network`    | name of the core CF network. | provided by Exodus data from your CF Genesis kit deployment |
| `cf_system_domain`   | the system domain for your CF deployment. | provided by Exodus data from your CF Genesis kit deployment |
| `skip_ssl_validation` | set to false to force ssl validation | true |
| `db_disk_type`       | the name of the persistent disk type to use for the local postgres VM. | `10GB`

## Features

In genesis kits features can be opted-in to on a per-environment bases by adding the `features` array to the environment file:
```
kit:
  features:
  - feature-a
  - feature-b
```

Using features is a way to configure the kit to suite the requirements of your specific deployment.

## Features Provided by the Genesis Kit

### `external-db`

Use this feature to use an external database instead of creating an internal one.  It supports the following parameters set under `bosh_variables:` in your environment.

| Key                 | Description                                                  | Default                                                    |
| ------------------- | ------------------------------------------------------------ | ---------------------------------------------------------- |
| `database.host`     | Required, the FQDN or IP for your database server            |                                                            |
| `database.port`     | The port the database server is listening on                 | 3306 for mysql, 5432 for postgres                          |
| `database.scheme`   | `postgres` or `mysql`                                        | `postgres`, or `mysql` if the `mysql` feature is specified |
| `database.name`     | Name of the database                                         | `autoscaler`                                               |
| `database.username` | Database authentication user name                            | `autoscaler`                                               |
| `database.password` | Database authentication password                             | Pulls from Credhub location `autoscaler_database_password` |
| `database.sslmode`  | Specifies the SSL validation mode to use; expect one of `disable`, `allow`, `prefer`, `require`, `verify-ca`, `verify-full` (*postgres*), `verify_identity` (*mysql*) | `verify-ca`                                                |
| `database.tls.ca`   | CA for the database server, set to "" if not using TLS       | Pulls from Credhub location `autoscaler_database_tls_ca`   |

It requires the following credhub values:

* `autoscaler_database_password` (password)
* `autoscaler_database_tls_ca` (certificate)

### `postgres`

This is the default database type, but can be explicitly stated.

### `mysql`

Use MySQL instead of PostgreSQL.

### `cf-v1-support`

Allows this kit to be applied to v1.x series of CF Genesis Kit.  See [Supporting or Upgrading from cf-genesis-kit v1.x.x](#supporting-or-upgrading-from-cf-genesis-kit-v1-x-x)

## Features Provided by `cf-app-autoscaler`

In addition to the bundled features that this kit exposes you can also include any ops files contained in the upstream [cf-app-autoscaler][cfaar] by referencing them via:
```
kit:
  features:
  - operations/<operation> # omit .yml suffix
```

Caveat: Not all features are compatible with this kit and features are applied in order, so ordering may matter.  At the time of this writing, there is only cf-mysql-db and external-db, which have more complete first-class Genesis features that should be used instead.

## Providing your Own Features

If you would like to apply additional ops-files for unsupported features you can do so by adding them under:
```
./ops/<feature-name>.yml
```

and reference them in your environment file via:
```
kit:
  features:
  - <feature-name>
```


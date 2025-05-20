# CF App Autoscaler Genesis Kit Manual

The **CF App Autoscaler Genesis Kit** allows you to create an App Autoscaler deployment to automatically scale applications in your existing Cloud Foundry based on predefined metrics and rules.

It is based on the upstream [cloudfoundry/app-autoscaler-release][cfaar], and supports both integrated and external PostgreSQL and MySQL databases. It's designed to work seamlessly with Cloud Foundry deployments created by cf-genesis-kit v2.0.0 or later, with provisions for pairing with any existing CF deployment.

[cfaar]: https://github.com/cloudfoundry/app-autoscaler-release

## Table of Contents

- [Requirements](#requirements)
- [General Usage Guidelines](#general-usage-guidelines)
- [Deployment Lifecycle](#deployment-lifecycle)
- [Migration from CF Genesis Kit v1.x.x](#migration-from-cf-genesis-kit-v1xx)
- [Base Parameters](#base-parameters)
- [Features](#features)
  - [ocfp](#ocfp)
  - [external-db](#external-db)
  - [subdomain_prefix](#subdomain_prefix)
  - [postgres](#postgres)
  - [mysql](#mysql)
  - [cf-v1-support](#cf-v1-support)
- [Upstream Features](#upstream-features)
- [Custom Features](#custom-features)
- [Post-Deployment Configuration](#post-deployment-configuration)
- [Scaling and Performance Tuning](#scaling-and-performance-tuning)
- [Troubleshooting](#troubleshooting)

## Requirements

### System Requirements

- **Genesis**: v2.8.5 or later
- **BOSH Director**: With Credhub enabled
- **Cloud Foundry**: Deployed via cf-genesis-kit v2.0.0 or later (recommended)
- **Memory**: Minimum 4GB RAM for the deployment
- **CPU**: Minimum 2 vCPUs for the deployment
- **Disk Space**: Minimum 20GB for database storage

### Credentials Management

This kit uses two distinct secrets management systems:

1. **Credhub**: For runtime secrets used by the deployment itself
2. **Vault**: For Exodus deployment metadata, as with all Genesis Kits

The Credhub provided by your BOSH director is used for each environment's secrets. The Vault used for metadata is configured when you run `genesis init` to create the deployment repository, and can be changed with `genesis secrets-provider -i`.

### Infrastructure Support

This kit supports deployment on multiple infrastructure providers. For details on VM types, networks, and other IaaS-specific configurations, see [Infrastructure Support](/docs/infrastructure-support.md).

## General Usage Guidelines

While you can theoretically attach this kit to any Cloud Foundry deployment, using the [CF Genesis Kit](https://github.com/genesis-community/cf-genesis-kit) is highly recommended for the best integration experience.

## Deployment Lifecycle

### Creating a New Deployment

1. **Create a Genesis deployment repository**:
   ```bash
   genesis init -k cf-app-autoscaler/4.1.2
   ```

2. **Create a new environment file**:
   ```bash
   cd cf-app-autoscaler-deployments
   genesis new my-env
   ```
   This will launch an interactive wizard to configure features and parameters.

3. **Review and modify the environment file** if needed:
   ```bash
   vim my-env.yml
   ```

4. **Deploy**:
   ```bash
   genesis deploy my-env
   ```

### Updating an Existing Deployment

1. **Update the kit** (if needed):
   ```bash
   genesis fetch-kit
   ```

2. **Modify environment features or parameters** if required:
   ```bash
   vim my-env.yml
   ```

3. **Deploy the updated configuration**:
   ```bash
   genesis deploy my-env
   ```

## Migration from CF Genesis Kit v1.x.x

If you're upgrading from a CF Genesis Kit with the built-in app autoscaler feature, follow these steps:

### Step 1: Backup Database (if using internal database)

Before disabling the autoscaler feature in your CF deployment:

```bash
# Connect to your CF database VM
bosh -d cf ssh postgres

# For PostgreSQL
pg_dump -U vcap autoscaler > /tmp/autoscaler_backup.sql

# For MySQL
mysqldump -u vcap -p autoscaler > /tmp/autoscaler_backup.sql

# Download the backup file
bosh -d cf scp postgres:/tmp/autoscaler_backup.sql ./
```

### Step 2: Disable Autoscaler in CF Deployment

1. Remove the autoscaler feature from your CF environment file:
   ```yaml
   kit:
     features:
     # Remove or comment out the autoscaler feature
     # - autoscaler
   ```

2. Deploy CF without the autoscaler:
   ```bash
   genesis deploy cf-env
   ```

### Step 3: Deploy Standalone Autoscaler

1. Create a new autoscaler environment file with the `cf-v1-support` feature:
   ```yaml
   kit:
     features:
     - cf-v1-support
     # Add other features as needed (mysql, external-db, etc.)

   bosh-variables:
     cf_client_id: (( vault meta.vault '/path/to/client_id' ))
     cf_client_secret: (( vault meta.vault '/path/to/client_secret' ))
     loggregator_ca:
       certificate: (( vault meta.vault '/path/to/loggregator_ca.certificate' ))
     loggregator_tls_agent:
       certificate: (( vault meta.vault '/path/to/loggregator_tls_agent.certificate' ))
       private_key: (( vault meta.vault '/path/to/loggregator_tls_agent.private_key' ))
     loggregator_tls_rlp:
       certificate: (( vault meta.vault '/path/to/loggregator_tls_rlp.certificate' ))
       private_key: (( vault meta.vault '/path/to/loggregator_tls_rlp.private_key' ))
   ```

2. Deploy the standalone autoscaler:
   ```bash
   genesis deploy autoscaler-env
   ```

### Step 4: Restore Database (if needed)

If using internal database and you need to restore data:

```bash
# For PostgreSQL
bosh -d autoscaler-env ssh postgres
psql -U vcap autoscaler < /tmp/autoscaler_backup.sql

# For MySQL
bosh -d autoscaler-env ssh mysql
mysql -u vcap -p autoscaler < /tmp/autoscaler_backup.sql
```

### Step 5: Future Migration to CF v2.x

Once you upgrade to CF Genesis Kit v2.x:

1. Remove the `cf-v1-support` feature from your autoscaler environment file
2. Redeploy the autoscaler:
   ```bash
   genesis deploy autoscaler-env
   ```

## Base Parameters

The following values can be specified in your environment file under `params:`:

| Key | Description | Default | Example |
| --- | ----------- | ------- | ------- |
| `cf_deployment_env` | Name of the CF deployment environment | The cf-app-autoscaler environment name | `production-cf` |
| `cf_deployment_type` | Type of deployment used for the CF deployment | `cf` | `cf` |
| `cf_core_network` | Name of the core CF network | Provided by Exodus data from CF Genesis kit | `cf-core` |
| `cf_system_domain` | System domain for your CF deployment | Provided by Exodus data from CF Genesis kit | `system.example.com` |
| `skip_ssl_validation` | Set to false to enforce SSL validation | `true` | `false` |
| `db_disk_type` | Persistent disk type for the local database VM | `10GB` | `50GB` |
| `subdomain_prefix` | Prefix for autoscaler subdomains | `autoscaler` | `aas` |

### Example environment file with basic parameters:

```yaml
---
kit:
  name:    cf-app-autoscaler
  version: 4.1.2
  features:
    - postgres

params:
  cf_deployment_env: prod-cf
  skip_ssl_validation: false
  db_disk_type: 20GB
```

## Features

Features can be enabled in your environment file by adding them to the `features` array:

```yaml
kit:
  features:
  - feature-a
  - feature-b
```

### `ocfp`

#### OCFP Reference Architecture

This reference architecture requires using an external database provisioned externally (typically with Terraform).

The OCFP deployment workflow follows:
1. **Terraform**: Computes values and places them in vault at contract-specified paths, e.g.: `secret/tf/{tf-env-path}/dbs/{bosh,credhub,uaa}`
2. **Database Initialization**: The `ocfp init pg` script initializes the database and populates the environment's database values in vault according to the contract: `secret/{env-path}/db/cf-app-autoscaler:{hostname,ca,...}`
3. **Environment Creation**: The `ocfp init env` script generates a Genesis BOSH kit environment file using a template that pulls values according to OCFP contracts
4. **Deployment**: Enable required features and deploy

The main differences with `ocfp` are that the following are specified according to contract, based on environment name:
- `azs`
- `networks`
- `vm_types` based on env scale (`params.ocfp_env_scale`: `prod` or `dev`, with `dev` as default)
- Location of external database and load balancer information in vault
- Organization and database certificate locations in vault

#### Example OCFP Configuration:

```yaml
kit:
  features:
  - ocfp

params:
  ocfp_env_scale: prod
```

### `external-db`

Use this feature to connect to an externally managed database instead of deploying one with the kit.

#### Configuration Parameters

Add these parameters under `bosh_variables:` in your environment file:

| Key | Description | Default | Example |
| --- | ----------- | ------- | ------- |
| `database.host` | FQDN or IP of your database server (required) | | `db.example.com` |
| `database.port` | Database server port | 3306 for MySQL, 5432 for PostgreSQL | `5432` |
| `database.scheme` | Database type: `postgres` or `mysql` | `postgres`, or `mysql` if the `mysql` feature is specified | `postgres` |
| `database.name` | Database name | `autoscaler` | `cf_autoscaler` |
| `database.username` | Database authentication username | `autoscaler` | `autoscaler_user` |
| `database.password` | Database authentication password | From Credhub: `autoscaler_database_password` | |
| `database.sslmode` | SSL validation mode | `verify-ca` | `require` |
| `database.tls.ca` | CA certificate for database server | From Credhub: `autoscaler_database_tls_ca` | |

#### Required Credhub Values:

* `autoscaler_database_password` (password)
* `autoscaler_database_tls_ca` (certificate)

#### Example External PostgreSQL Configuration:

```yaml
kit:
  features:
  - external-db
  - postgres

bosh_variables:
  database:
    host: postgres.example.com
    port: 5432
    name: cf_autoscaler
    username: autoscaler_admin
    password: (( vault meta.vault '/databases/postgres/autoscaler:password' ))
    sslmode: verify-ca
    tls:
      ca: (( vault meta.vault '/databases/postgres/autoscaler:ca' ))
```

#### Example External MySQL Configuration:

```yaml
kit:
  features:
  - external-db
  - mysql

bosh_variables:
  database:
    host: mysql.example.com
    port: 3306
    scheme: mysql
    name: cf_autoscaler
    username: autoscaler_admin
    password: (( vault meta.vault '/databases/mysql/autoscaler:password' ))
    sslmode: verify_identity
    tls:
      ca: (( vault meta.vault '/databases/mysql/autoscaler:ca' ))
```

### `subdomain_prefix`

By default, the subdomain prefix is `autoscaler`, resulting in these URLs:
* `autoscaler.${system_domain}`
* `autoscalermetrics.${system_domain}`
* `autoscalerservicebroker.${system_domain}`

You can override this prefix in the environment file:

```yaml
params:
  subdomain_prefix: "aas"
```

This would create the following URLs:
* `aas.${system_domain}`
* `aasmetrics.${system_domain}`
* `aasservicebroker.${system_domain}`

### `postgres`

This is the default database type but can be explicitly specified. When used without `external-db`, a PostgreSQL server will be deployed as part of your BOSH deployment.

```yaml
kit:
  features:
  - postgres
```

### `mysql`

Use MySQL instead of PostgreSQL. When used without `external-db`, a MySQL server will be deployed as part of your BOSH deployment.

```yaml
kit:
  features:
  - mysql
```

### `cf-v1-support`

Allows this kit to be applied to the v1.x series of CF Genesis Kit. See [Migration from CF Genesis Kit v1.x.x](#migration-from-cf-genesis-kit-v1xx) for details.

## Upstream Features

In addition to the bundled features, you can include ops files from the upstream [cf-app-autoscaler][cfaar] release:

```yaml
kit:
  features:
  - operations/<operation> # omit .yml suffix
```

**Note**: Not all upstream features are compatible with this kit, and features are applied in order, so ordering matters. Currently, most upstream features have more complete first-class Genesis features that should be used instead.

## Custom Features

You can add custom ops files for features not directly supported by the kit:

1. Create a custom ops file in your deployment repository:
   ```bash
   mkdir -p ops
   vim ops/my-custom-feature.yml
   ```

2. Reference it in your environment file:
   ```yaml
   kit:
     features:
     - my-custom-feature
   ```

## Post-Deployment Configuration

After deployment, complete the setup with these addon commands:

### Install the CF CLI Plugin

```bash
genesis do my-env setup-cf-plugin
```

### Bind Autoscaler Service Broker to CF

```bash
genesis do my-env bind-autoscaler
```

### Create Autoscaling Policies

Use the interactive configuration tool:

```bash
genesis do my-env config-autoscaler
```

For more details on configuring autoscaling policies, see [Autoscaler Configuration](/docs/config-autoscaler.md).

## Scaling and Performance Tuning

### Database Sizing

For production environments, adjust the database disk size according to your needs:

```yaml
params:
  db_disk_type: 50GB
```

### Resource Allocation

For high-load environments, consider adjusting VM types in your cloud config for better performance.

### Service Instance Counts

The default instance count for the service is 1. For production environments, consider increasing this:

```yaml
instance_groups:
- name: api
  instances: 2
- name: scheduler
  instances: 2
```

## Troubleshooting

### Common Issues

#### Service Broker Registration Failure

If the service broker registration fails, check:
- CF API accessibility
- Credentials correctness
- Network connectivity between CF and Autoscaler

Debug with:
```bash
genesis do my-env test-bind-autoscaler
```

#### Database Connection Issues

If you encounter database connection problems:
1. Verify database credentials are correct
2. Check network connectivity to the database
3. Ensure firewall rules allow traffic on the database port
4. Verify TLS certificates if using secure connections

#### Scaling Doesn't Work

If applications don't scale as expected:
1. Verify the policy is correctly applied: `cf autoscaling-policy APP_NAME`
2. Check metrics collection: `cf autoscaling-metrics APP_NAME`
3. Examine logs: `bosh -d my-env-cf-app-autoscaler logs`

### Getting Help

If you encounter persistent issues:
1. Check the [GitHub repository](https://github.com/genesis-community/cf-app-autoscaler-genesis-kit) for known issues
2. Review the [upstream documentation](https://github.com/cloudfoundry/app-autoscaler-release)
3. Reach out to the Genesis community for assistance

---

[cfaar]: https://github.com/cloudfoundry/app-autoscaler-release
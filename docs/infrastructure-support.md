# Infrastructure Support for CF App Autoscaler Genesis Kit

This document details the supported infrastructure providers (IaaS) for the CF App Autoscaler Genesis Kit.

## Supported IaaS Providers

The CF App Autoscaler Genesis Kit supports the following infrastructure providers:

### OpenStack

The kit supports OpenStack as an infrastructure provider with the following configurations:

- Network configuration with security groups
- VM types for all App Autoscaler components with configurable instance sizes
- Persistent disk configuration for database storage

### STACKIT

STACKIT support has been added with configurations that mirror OpenStack:

- Network configuration with security groups, accounting for STACKIT's 1:1 network to subnet mapping
- VM types for all App Autoscaler components with the same instance types as OpenStack
- Persistent disk configuration for database storage

## IaaS-Specific Configuration Details

### OpenStack

For OpenStack deployments, the kit uses:

- `net_id` and `security_groups` for network configuration
- Instance types scaled by environment (`m1.small` for dev, `m1.medium` for prod)
- Boot from volume with 20GB root disk
- Premium storage type for persistent disks

### STACKIT

STACKIT uses the same configuration approach as OpenStack:

- `net_id` and `security_groups` for network configuration, with consideration for STACKIT's 1:1 network-to-subnet mapping
- Instance types scaled by environment (`m1.small` for dev, `m1.medium` for prod)
- Boot from volume with 20GB root disk
- Premium storage type for persistent disks

## Adding Support for Additional IaaS Providers

To add support for additional IaaS providers:

1. Locate the `cloud-config.pm` file in the `hooks/` directory
2. Add the new IaaS provider configurations to the following sections:
   - Network configuration under `cloud_properties_for_iaas`
   - VM type configurations for each component
   - Disk type configurations
3. Follow the pattern used for existing providers while accounting for any specific IaaS requirements
# Infrastructure Support for CF App Autoscaler Genesis Kit

This document details the supported infrastructure providers (IaaS) for the CF App Autoscaler Genesis Kit, along with configuration guidance and best practices for each platform.

## Table of Contents

- [Supported Infrastructure Providers](#supported-infrastructure-providers)
  - [OpenStack](#openstack)
  - [STACKIT](#stackit)
  - [AWS](#aws)
  - [Azure](#azure)
  - [Google Cloud Platform (GCP)](#google-cloud-platform-gcp)
  - [VMware vSphere](#vmware-vsphere)
- [IaaS-Specific Configuration Details](#iaas-specific-configuration-details)
  - [OpenStack Configuration](#openstack-configuration)
  - [STACKIT Configuration](#stackit-configuration)
  - [AWS Configuration](#aws-configuration)
  - [Azure Configuration](#azure-configuration)
  - [GCP Configuration](#gcp-configuration)
  - [vSphere Configuration](#vsphere-configuration)
- [Network and Security Requirements](#network-and-security-requirements)
- [Resource Sizing Recommendations](#resource-sizing-recommendations)
- [Adding Support for Additional IaaS Providers](#adding-support-for-additional-iaas-providers)

## Supported Infrastructure Providers

The CF App Autoscaler Genesis Kit can be deployed on various infrastructure providers. Each provider has specific configurations that ensure optimal performance.

### OpenStack

The kit fully supports OpenStack with the following configurations:

- Network configuration with security groups
- VM types for all App Autoscaler components with configurable instance sizes
- Persistent disk configuration for database storage
- Support for availability zones and anti-affinity

### STACKIT

STACKIT support has been implemented with configurations that mirror OpenStack:

- Network configuration with security groups, accounting for STACKIT's 1:1 network to subnet mapping
- VM types for all App Autoscaler components with the same instance types as OpenStack
- Persistent disk configuration for database storage
- Availability zone support for high availability

### AWS

While not officially tested, the CF App Autoscaler Genesis Kit should work on AWS with proper cloud config settings:

- VPC and subnet configuration
- Security group settings
- Amazon EC2 instance types
- EBS volumes for persistent storage
- Multiple availability zone support

### Azure

Azure deployments should work with appropriate cloud config settings:

- Resource groups and VNet configuration
- Network security groups
- VM sizes for Azure
- Managed disk configuration
- Availability zones configuration

### Google Cloud Platform (GCP)

GCP deployments should work with appropriate cloud config settings:

- Network and subnetwork configuration
- Firewall rules for security
- GCP machine types
- Persistent disk configuration
- Zone and region settings

### VMware vSphere

vSphere deployments should work with appropriate cloud config settings:

- Resource pool configuration
- Folder and datastore settings
- Network configuration
- VM hardware settings
- Disk configuration

## IaaS-Specific Configuration Details

### OpenStack Configuration

OpenStack deployments use the following configuration:

#### Networks

```yaml
networks:
- name: cf-autoscaler
  subnets:
  - cloud_properties:
      net_id: <network-id>
      security_groups: [<security-group>]
    gateway: <gateway-ip>
    range: <cidr-range>
    reserved: [<reserved-ip-ranges>]
    static: [<static-ip-ranges>]
```

#### VM Types

```yaml
vm_types:
- name: default
  cloud_properties:
    instance_type: m1.small
    root_disk_size: 20
```

For production environments:

```yaml
vm_types:
- name: default
  cloud_properties:
    instance_type: m1.medium
    root_disk_size: 20
```

#### Disk Types

```yaml
disk_types:
- name: default
  disk_size: 10240
  cloud_properties:
    type: Premium_LRS
- name: large
  disk_size: 51200
  cloud_properties:
    type: Premium_LRS
```

### STACKIT Configuration

STACKIT uses the same configuration approach as OpenStack with these key differences:

- Network configuration accounts for STACKIT's 1:1 network-to-subnet mapping
- Security groups are configured specifically for STACKIT's networking model

```yaml
networks:
- name: cf-autoscaler
  subnets:
  - cloud_properties:
      net_id: <stackit-network-id>
      security_groups: [<stackit-security-group>]
    gateway: <gateway-ip>
    range: <cidr-range>
    reserved: [<reserved-ip-ranges>]
    static: [<static-ip-ranges>]
```

### AWS Configuration

For AWS deployments, your cloud config should include:

#### Networks

```yaml
networks:
- name: cf-autoscaler
  subnets:
  - cloud_properties:
      subnet: <subnet-id>
      security_groups: [<security-group-id>]
    gateway: <gateway-ip>
    range: <cidr-range>
    reserved: [<reserved-ip-ranges>]
    static: [<static-ip-ranges>]
```

#### VM Types

```yaml
vm_types:
- name: default
  cloud_properties:
    instance_type: t3.small
    ephemeral_disk:
      size: 20_000
      type: gp2
```

For production environments:

```yaml
vm_types:
- name: default
  cloud_properties:
    instance_type: t3.medium
    ephemeral_disk:
      size: 20_000
      type: gp2
```

#### Disk Types

```yaml
disk_types:
- name: default
  disk_size: 10240
  cloud_properties:
    type: gp2
- name: large
  disk_size: 51200
  cloud_properties:
    type: gp2
```

### Azure Configuration

For Azure deployments, your cloud config should include:

#### Networks

```yaml
networks:
- name: cf-autoscaler
  subnets:
  - cloud_properties:
      virtual_network_name: <vnet-name>
      subnet_name: <subnet-name>
      security_group: <nsg-name>
    gateway: <gateway-ip>
    range: <cidr-range>
    reserved: [<reserved-ip-ranges>]
    static: [<static-ip-ranges>]
```

#### VM Types

```yaml
vm_types:
- name: default
  cloud_properties:
    instance_type: Standard_DS2_v2
    root_disk:
      size: 20_000
```

For production environments:

```yaml
vm_types:
- name: default
  cloud_properties:
    instance_type: Standard_DS3_v2
    root_disk:
      size: 20_000
```

#### Disk Types

```yaml
disk_types:
- name: default
  disk_size: 10240
  cloud_properties:
    type: Premium_LRS
- name: large
  disk_size: 51200
  cloud_properties:
    type: Premium_LRS
```

### GCP Configuration

For GCP deployments, your cloud config should include:

#### Networks

```yaml
networks:
- name: cf-autoscaler
  subnets:
  - cloud_properties:
      network_name: <network-name>
      subnetwork_name: <subnet-name>
      tags: [<tags>]
    gateway: <gateway-ip>
    range: <cidr-range>
    reserved: [<reserved-ip-ranges>]
    static: [<static-ip-ranges>]
```

#### VM Types

```yaml
vm_types:
- name: default
  cloud_properties:
    machine_type: n1-standard-1
    root_disk_size_gb: 20
    root_disk_type: pd-ssd
```

For production environments:

```yaml
vm_types:
- name: default
  cloud_properties:
    machine_type: n1-standard-2
    root_disk_size_gb: 20
    root_disk_type: pd-ssd
```

#### Disk Types

```yaml
disk_types:
- name: default
  disk_size: 10240
  cloud_properties:
    type: pd-ssd
- name: large
  disk_size: 51200
  cloud_properties:
    type: pd-ssd
```

### vSphere Configuration

For vSphere deployments, your cloud config should include:

#### Networks

```yaml
networks:
- name: cf-autoscaler
  subnets:
  - cloud_properties:
      name: <network-name>
    gateway: <gateway-ip>
    range: <cidr-range>
    reserved: [<reserved-ip-ranges>]
    static: [<static-ip-ranges>]
```

#### VM Types

```yaml
vm_types:
- name: default
  cloud_properties:
    cpu: 2
    ram: 4096
    disk: 20_000
```

For production environments:

```yaml
vm_types:
- name: default
  cloud_properties:
    cpu: 4
    ram: 8192
    disk: 20_000
```

#### Disk Types

```yaml
disk_types:
- name: default
  disk_size: 10240
- name: large
  disk_size: 51200
```

## Network and Security Requirements

### Network Requirements

The CF App Autoscaler requires connectivity to:

1. **Cloud Foundry API**: Access to the CF API endpoints for service broker registration
2. **Cloud Foundry applications**: Access to application metrics and scaling endpoints
3. **Database**: Either internal or external database connectivity
4. **BOSH Director**: For deployment management

### Security Requirements

Minimum security configurations include:

1. **Firewall rules**:
   - Allow inbound traffic to the Autoscaler API (typically port 80/443)
   - Allow outbound traffic to CF API and applications
   - Allow database connectivity (PostgreSQL 5432 or MySQL 3306)

2. **TLS certificates**:
   - Service endpoints should be secured with TLS
   - Database connections should use TLS where possible

3. **Network segregation**:
   - Consider placing the Autoscaler in the same network as CF components
   - For external databases, ensure proper network ACLs

## Resource Sizing Recommendations

The following resource recommendations are based on the scale of your Cloud Foundry deployment:

### Small (< 50 applications)

- **CPU**: 2 vCPUs
- **Memory**: 4GB RAM
- **Disk**: 10GB persistent disk for database
- **VM type**: Equivalent to `t3.small` (AWS), `Standard_DS2_v2` (Azure), `n1-standard-1` (GCP), `m1.small` (OpenStack)

### Medium (50-200 applications)

- **CPU**: 4 vCPUs
- **Memory**: 8GB RAM
- **Disk**: 20GB persistent disk for database
- **VM type**: Equivalent to `t3.medium` (AWS), `Standard_DS3_v2` (Azure), `n1-standard-2` (GCP), `m1.medium` (OpenStack)

### Large (> 200 applications)

- **CPU**: 8 vCPUs
- **Memory**: 16GB RAM
- **Disk**: 50GB persistent disk for database
- **VM type**: Equivalent to `t3.large` (AWS), `Standard_DS4_v2` (Azure), `n1-standard-4` (GCP), `m1.large` (OpenStack)

## Adding Support for Additional IaaS Providers

To add support for additional IaaS providers:

1. Locate the `cloud-config.pm` file in the `hooks/` directory
2. Add the new IaaS provider configurations to the following sections:
   - Network configuration under `cloud_properties_for_iaas`
   - VM type configurations for each component
   - Disk type configurations
3. Follow the pattern used for existing providers while accounting for any specific IaaS requirements
4. Test with a small deployment before deploying to production
5. Consider contributing your changes back to the CF App Autoscaler Genesis Kit repository

### Implementation Example

```perl
sub cloud_properties_for_iaas {
  my ($self, $iaas, $net_type) = @_;
  
  if ($iaas eq 'new-iaas-provider') {
    return (
      # Add cloud properties specific to the new IaaS provider
    );
  }
  
  # Existing providers...
}
```
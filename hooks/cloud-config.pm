package Genesis::Hook::CloudConfig::AppAutoscaler;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::CloudConfig);

use Genesis::Hook::CloudConfig::Helpers qw/gigabytes megabytes/;

use Genesis qw/bail/;
use JSON::PP;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;
  return 1 if $self->completed;

  # Build cloud configuration with support for OpenStack, STACKIT, and AWS IaaS providers
  # STACKIT configuration mirrors OpenStack but accounts for 1:1 network to subnet mapping
  # AWS configuration based on extracted cloud config with encrypted disks and appropriate instance types
  my $config = $self->build_cloud_config({
    'networks' => [
      $self->network_definition('autoscaler', strategy => 'ocfp',
        dynamic_subnets => {
          allocation => {
            size => 0,
            statics => 0,
          },
          cloud_properties_for_iaas => {
            openstack => {
              'net_id' => $self->network_reference('id'),
              'security_groups' => ['default']
            },
            # STACKIT IaaS configuration - similar to OpenStack but with 1:1 network to subnet mapping
            stackit => {
              'net_id' => $self->network_reference('id'),
              'security_groups' => ['default']
            },
            # AWS IaaS configuration
            aws => {
              'subnet' => $self->network_reference('id'),
              'security_groups' => ['default']
            },
          },
        },
      )
    ],
    'vm_types' => [
      # VM types for each component - defined for OpenStack, STACKIT, and AWS
      # AWS specific configuration follows the aws-cloud-config.yml implementation
      $self->vm_type_definition('as-api',
        cloud_properties_for_iaas => {
          openstack => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 20 # in gigabytes
            },
          },
          stackit => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 20 # in gigabytes
            },
          },
          # AWS IaaS VM configuration for API component
          aws => {
            'instance_type' => $self->for_scale({
              dev => 't3.medium',
              prod => 'm6i.large'
            }, 't3.medium'),
            'ephemeral_disk' => {
              'size' => $self->for_scale({
                dev => 4096,
                prod => 16384
              }, 4096),
              'type' => 'gp3',
              'encrypted' => $self->TRUE
            },
            'metadata_options' => {
              'http_tokens' => 'required'
            },
          },
        },
      ),
      $self->vm_type_definition('as-actors',
        cloud_properties_for_iaas => {
          openstack => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 20 # in gigabytes
            },
          },
          stackit => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 20 # in gigabytes
            },
          },
          # AWS IaaS VM configuration for actors component
          aws => {
            'instance_type' => $self->for_scale({
              dev => 't3.medium',
              prod => 'm6i.large'
            }, 't3.medium'),
            'ephemeral_disk' => {
              'size' => $self->for_scale({
                dev => 4096,
                prod => 16384
              }, 4096),
              'type' => 'gp3',
              'encrypted' => $self->TRUE
            },
            'metadata_options' => {
              'http_tokens' => 'required'
            },
          },
        },
      ),
      $self->vm_type_definition('as-metrics',
        cloud_properties_for_iaas => {
          openstack => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 20 # in gigabytes
            },
          },
          stackit => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 20 # in gigabytes
            },
          },
          # AWS IaaS VM configuration for metrics component
          aws => {
            'instance_type' => $self->for_scale({
              dev => 't3.medium',
              prod => 'm6i.xlarge'
            }, 't3.medium'),
            'ephemeral_disk' => {
              'size' => $self->for_scale({
                dev => 4096,
                prod => 16384
              }, 4096),
              'type' => 'gp3',
              'encrypted' => $self->TRUE
            },
            'metadata_options' => {
              'http_tokens' => 'required'
            },
          },
        },
      ),
      $self->vm_type_definition('as-nozzle',
        cloud_properties_for_iaas => {
          openstack => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 20 # in gigabytes
            },
          },
          stackit => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 20 # in gigabytes
            },
          },
          # AWS IaaS VM configuration for nozzle component
          aws => {
            'instance_type' => $self->for_scale({
              dev => 't3.medium',
              prod => 'm6i.xlarge'
            }, 't3.medium'),
            'ephemeral_disk' => {
              'size' => $self->for_scale({
                dev => 4096,
                prod => 16384
              }, 4096),
              'type' => 'gp3',
              'encrypted' => $self->TRUE
            },
            'metadata_options' => {
              'http_tokens' => 'required'
            },
          },
        },
      ),
      $self->vm_type_definition('as-apiserver',
        cloud_properties_for_iaas => {
          openstack => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 20 # in gigabytes
            },
          },
          stackit => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 20 # in gigabytes
            },
          },
          # AWS IaaS VM configuration
          aws => {
            'instance_type' => $self->for_scale({
              dev => 't3.medium',
              prod => 'm6i.large'
            }, 't3.medium'),
            'ephemeral_disk' => {
              'size' => $self->for_scale({
                dev => 4096,
                prod => 16384
              }, 4096),
              'type' => 'gp3',
              'encrypted' => $self->TRUE
            },
            'metadata_options' => {
              'http_tokens' => 'required'
            },
          },
        },
      ),
      $self->vm_type_definition('as-scalingengine',
        cloud_properties_for_iaas => {
          openstack => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 20 # in gigabytes
            },
          },
          stackit => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 20 # in gigabytes
            },
          },
          # AWS IaaS VM configuration
          aws => {
            'instance_type' => $self->for_scale({
              dev => 't3.medium',
              prod => 'm6i.large'
            }, 't3.medium'),
            'ephemeral_disk' => {
              'size' => $self->for_scale({
                dev => 4096,
                prod => 16384
              }, 4096),
              'type' => 'gp3',
              'encrypted' => $self->TRUE
            },
            'metadata_options' => {
              'http_tokens' => 'required'
            },
          },
        },
      ),
      $self->vm_type_definition('as-scheduler',
        cloud_properties_for_iaas => {
          openstack => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 20 # in gigabytes
            },
          },
          stackit => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 20 # in gigabytes
            },
          },
          # AWS IaaS VM configuration - scheduler uses m6i.xlarge for prod
          aws => {
            'instance_type' => $self->for_scale({
              dev => 't3.medium',
              prod => 'm6i.xlarge'
            }, 't3.medium'),
            'ephemeral_disk' => {
              'size' => $self->for_scale({
                dev => 4096,
                prod => 16384
              }, 4096),
              'type' => 'gp3',
              'encrypted' => $self->TRUE
            },
            'metadata_options' => {
              'http_tokens' => 'required'
            },
          },
        },
      ),
      $self->vm_type_definition('as-operator',
        cloud_properties_for_iaas => {
          openstack => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 20 # in gigabytes
            },
          },
          stackit => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 20 # in gigabytes
            },
          },
          # AWS IaaS VM configuration - operator uses m6i.xlarge for prod
          aws => {
            'instance_type' => $self->for_scale({
              dev => 't3.medium',
              prod => 'm6i.xlarge'
            }, 't3.medium'),
            'ephemeral_disk' => {
              'size' => $self->for_scale({
                dev => 4096,
                prod => 16384
              }, 4096),
              'type' => 'gp3',
              'encrypted' => $self->TRUE
            },
            'metadata_options' => {
              'http_tokens' => 'required'
            },
          },
        },
      ),
      $self->vm_type_definition('as-eventgenerator',
        cloud_properties_for_iaas => {
          openstack => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 20 # in gigabytes
            },
          },
          stackit => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 20 # in gigabytes
            },
          },
          # AWS IaaS VM configuration - eventgenerator uses m6i.xlarge for prod
          aws => {
            'instance_type' => $self->for_scale({
              dev => 't3.medium',
              prod => 'm6i.xlarge'
            }, 't3.medium'),
            'ephemeral_disk' => {
              'size' => $self->for_scale({
                dev => 4096,
                prod => 16384
              }, 4096),
              'type' => 'gp3',
              'encrypted' => $self->TRUE
            },
            'metadata_options' => {
              'http_tokens' => 'required'
            },
          },
        },
      ),
      $self->vm_type_definition('as-metricsforwarder',
        cloud_properties_for_iaas => {
          openstack => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 20 # in gigabytes
            },
          },
          stackit => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 20 # in gigabytes
            },
          },
          # AWS IaaS VM configuration - metricsforwarder uses m6i.xlarge for prod
          aws => {
            'instance_type' => $self->for_scale({
              dev => 't3.medium',
              prod => 'm6i.xlarge'
            }, 't3.medium'),
            'ephemeral_disk' => {
              'size' => $self->for_scale({
                dev => 4096,
                prod => 16384
              }, 4096),
              'type' => 'gp3',
              'encrypted' => $self->TRUE
            },
            'metadata_options' => {
              'http_tokens' => 'required'
            },
          },
        },
      ),
    ],
    'disk_types' => [
      # Disk type configurations for OpenStack, STACKIT, and AWS
      # Following the aws-cloud-config.yml implementation with separate disk types for components
      $self->disk_type_definition('as-api',
        common => {
          disk_size => $self->for_scale({
            dev => gigabytes(32),
            prod => gigabytes(64)
          }, gigabytes(32)),
        },
        cloud_properties_for_iaas => {
          openstack => {
            'type' => 'storage_premium_perf1',
          },
          stackit => {
            'type' => 'storage_premium_perf1',
          },
          aws => {
            'type' => 'gp3',
            'encrypted' => $self->TRUE,
          },
        },
      ),
      $self->disk_type_definition('as-actors',
        common => {
          disk_size => $self->for_scale({
            dev => gigabytes(32),
            prod => gigabytes(64)
          }, gigabytes(32)),
        },
        cloud_properties_for_iaas => {
          openstack => {
            'type' => 'storage_premium_perf1',
          },
          stackit => {
            'type' => 'storage_premium_perf1',
          },
          aws => {
            'type' => 'gp3',
            'encrypted' => $self->TRUE,
          },
        },
      ),
      $self->disk_type_definition('as-metrics',
        common => {
          disk_size => $self->for_scale({
            dev => gigabytes(32),
            prod => gigabytes(64)
          }, gigabytes(32)),
        },
        cloud_properties_for_iaas => {
          openstack => {
            'type' => 'storage_premium_perf1',
          },
          stackit => {
            'type' => 'storage_premium_perf1',
          },
          aws => {
            'type' => 'gp3',
            'encrypted' => $self->TRUE,
          },
        },
      ),
      $self->disk_type_definition('as-nozzle',
        common => {
          disk_size => $self->for_scale({
            dev => gigabytes(32),
            prod => gigabytes(64)
          }, gigabytes(32)),
        },
        cloud_properties_for_iaas => {
          openstack => {
            'type' => 'storage_premium_perf1',
          },
          stackit => {
            'type' => 'storage_premium_perf1',
          },
          aws => {
            'type' => 'gp3',
            'encrypted' => $self->TRUE,
          },
        },
      ),
      $self->disk_type_definition('as-apiserver',
        common => {
          disk_size => $self->for_scale({
            dev => gigabytes(32),
            prod => gigabytes(64)
          }, gigabytes(32)),
        },
        cloud_properties_for_iaas => {
          openstack => {
            'type' => 'storage_premium_perf1',
          },
          stackit => {
            'type' => 'storage_premium_perf1',
          },
          aws => {
            'type' => 'gp3',
            'encrypted' => $self->TRUE,
          },
        },
      ),
      $self->disk_type_definition('as-scalingengine',
        common => {
          disk_size => $self->for_scale({
            dev => gigabytes(32),
            prod => gigabytes(64)
          }, gigabytes(32)),
        },
        cloud_properties_for_iaas => {
          openstack => {
            'type' => 'storage_premium_perf1',
          },
          stackit => {
            'type' => 'storage_premium_perf1',
          },
          aws => {
            'type' => 'gp3',
            'encrypted' => $self->TRUE,
          },
        },
      ),
      $self->disk_type_definition('as-scheduler',
        common => {
          disk_size => $self->for_scale({
            dev => gigabytes(32),
            prod => gigabytes(64)
          }, gigabytes(32)),
        },
        cloud_properties_for_iaas => {
          openstack => {
            'type' => 'storage_premium_perf1',
          },
          stackit => {
            'type' => 'storage_premium_perf1',
          },
          aws => {
            'type' => 'gp3',
            'encrypted' => $self->TRUE,
          },
        },
      ),
      $self->disk_type_definition('as-operator',
        common => {
          disk_size => $self->for_scale({
            dev => gigabytes(32),
            prod => gigabytes(64)
          }, gigabytes(32)),
        },
        cloud_properties_for_iaas => {
          openstack => {
            'type' => 'storage_premium_perf1',
          },
          stackit => {
            'type' => 'storage_premium_perf1',
          },
          aws => {
            'type' => 'gp3',
            'encrypted' => $self->TRUE,
          },
        },
      ),
      $self->disk_type_definition('as-metricsforwarder',
        common => {
          disk_size => $self->for_scale({
            dev => gigabytes(32),
            prod => gigabytes(64)
          }, gigabytes(32)),
        },
        cloud_properties_for_iaas => {
          openstack => {
            'type' => 'storage_premium_perf1',
          },
          stackit => {
            'type' => 'storage_premium_perf1',
          },
          aws => {
            'type' => 'gp3',
            'encrypted' => $self->TRUE,
          },
        },
      ),
      $self->disk_type_definition('as-eventgenerator',
        common => {
          disk_size => $self->for_scale({
            dev => gigabytes(32),
            prod => gigabytes(64)
          }, gigabytes(32)),
        },
        cloud_properties_for_iaas => {
          openstack => {
            'type' => 'storage_premium_perf1',
          },
          stackit => {
            'type' => 'storage_premium_perf1',
          },
          aws => {
            'type' => 'gp3',
            'encrypted' => $self->TRUE,
          },
        },
      ),
      # Keep the as-db for backward compatibility
      $self->disk_type_definition('as-db',
        common => {
          disk_size => $self->for_scale({
            dev => gigabytes(5),
            prod => gigabytes(10)
          }, gigabytes(5)),
        },
        cloud_properties_for_iaas => {
          openstack => {
            'type' => 'storage_premium_perf1',
          },
          # STACKIT IaaS disk configuration - using same storage type as OpenStack
          stackit => {
            'type' => 'storage_premium_perf1',
          },
          # AWS IaaS disk configuration
          aws => {
            'type' => 'gp3',
            'encrypted' => $self->TRUE,
          },
        },
      ),
    ],
  });

  $self->done($config);

	return 1;

}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:

#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::CloudConfig::AppAutoscaler v4.0.0;

use strict;
use warnings;
use v5.20;

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
          },
        },
      )
    ],
    'vm_types' => [
      # VM types for each component
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
        },
      ),
    ],
    'disk_types' => [
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
        },
      ),
    ],
  });

  $self->done($config);
}

1;


package Genesis::Hook::CloudConfig::Autoscaler v2.6.0;

use strict;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::CloudConfig);

use Genesis::Hook::CloudConfig::Helpers qw/gigabytes megabytes/;

use Genesis qw//;
use JSON::PP;

sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0');
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
						size => 7,
					},
					cloud_properties_for_iaas => {
						'openstack' => {
							'net_id' => $self->network_reference('id'),
							'security_groups' => $self->get_network_security_groups(),
						},
						'aws' => {
							'subnet' => $self->subnet_reference('id'),
							'security_groups' => $self->get_network_security_groups(),
						},
						'stackit' => {
							'net_id' => $self->network_reference('id'),
							'security_groups' => $self->get_network_security_groups(),
						},
					},
				},
			)
		],
		'vm_types' => [
			$self->vm_type_definition('postgres',
				cloud_properties_for_iaas => {
					openstack => {
						'instance_type' => $self->for_scale({
							dev => 'g1.2',
							prod => 'g1.3'
						}, 'g1.2'),
						'boot_from_volume' => $self->TRUE,
						'root_disk' => {
							'size' => 30
						},
					},
					stackit => {
						'instance_type' => $self->for_scale({
							dev => 't2i.1',
							prod => 'g2i.2'
						}, 'g2i.1'),
						'boot_from_volume' => $self->TRUE,
						'root_disk' => {
							'size' => 30 # in gigabytes
						},
					},
					aws => {
						'instance_type' => $self->for_scale({
							dev => 't3.medium',
							prod => 'm6i.large'
						}, 't3.medium'),
						'ephemeral_disk' => {
							'size' => $self->for_scale({
								dev => 30720,
								prod => 131072
							}, 4096),
							'type' => 'gp3',
							'encrypted' => $self->TRUE
						},
						'metadata_options' => {
							'http_tokens' => 'required'
						},
					},
				}
			),
			$self->vm_type_definition('apiserver',
				cloud_properties_for_iaas => {
					openstack => {
						'instance_type' => $self->for_scale({
							dev => 'g1.2',
							prod => 'g1.3'
						}, 'g1.2'),
						'boot_from_volume' => $self->TRUE,
						'root_disk' => {
							'size' => 30
						},
					},
					stackit => {
						'instance_type' => $self->for_scale({
							dev => 't2i.1',
							prod => 'g2i.2'
						}, 'g2i.1'),
						'boot_from_volume' => $self->TRUE,
						'root_disk' => {
							'size' => 30 # in gigabytes
						},
					},
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
				}
			),
			$self->vm_type_definition('scalingengine',
				cloud_properties_for_iaas => {
					openstack => {
						'instance_type' => $self->for_scale({
							dev => 'g1.2',
							prod => 'g1.3'
						}, 'g1.2'),
						'boot_from_volume' => $self->TRUE,
						'root_disk' => {
							'size' => 30
						},
					},
					stackit => {
						'instance_type' => $self->for_scale({
							dev => 't2i.1',
							prod => 'g2i.2'
						}, 'g2i.1'),
						'boot_from_volume' => $self->TRUE,
						'root_disk' => {
							'size' => 30 # in gigabytes
						},
					},
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
				}
			),
			$self->vm_type_definition('scheduler',
				cloud_properties_for_iaas => {
					openstack => {
						'instance_type' => $self->for_scale({
							dev => 'g1.2',
							prod => 'g1.3'
						}, 'g1.2'),
						'boot_from_volume' => $self->TRUE,
						'root_disk' => {
							'size' => 30
						},
					},
					stackit => {
						'instance_type' => $self->for_scale({
							dev => 't2i.1',
							prod => 'g2i.2'
						}, 'g2i.1'),
						'boot_from_volume' => $self->TRUE,
						'root_disk' => {
							'size' => 30 # in gigabytes
						},
					},
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
				}
			),
			$self->vm_type_definition('operator',
				cloud_properties_for_iaas => {
					openstack => {
						'instance_type' => $self->for_scale({
							dev => 'g1.2',
							prod => 'g1.3'
						}, 'g1.2'),
						'boot_from_volume' => $self->TRUE,
						'root_disk' => {
							'size' => 30
						},
					},
					stackit => {
						'instance_type' => $self->for_scale({
							dev => 't2i.1',
							prod => 'g2i.2'
						}, 'g2i.1'),
						'boot_from_volume' => $self->TRUE,
						'root_disk' => {
							'size' => 30 # in gigabytes
						},
					},
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
				}
			),
			$self->vm_type_definition('eventgenerator',
				cloud_properties_for_iaas => {
					openstack => {
						'instance_type' => $self->for_scale({
							dev => 'g1.2',
							prod => 'g1.3'
						}, 'g1.2'),
						'boot_from_volume' => $self->TRUE,
						'root_disk' => {
							'size' => 30
						},
					},
					stackit => {
						'instance_type' => $self->for_scale({
							dev => 't2i.1',
							prod => 'g2i.2'
						}, 'g2i.1'),
						'boot_from_volume' => $self->TRUE,
						'root_disk' => {
							'size' => 30 # in gigabytes
						},
					},
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
				}
			),
			$self->vm_type_definition('metricsforwarder',
				cloud_properties_for_iaas => {
					openstack => {
						'instance_type' => $self->for_scale({
							dev => 'g1.2',
							prod => 'g1.3'
						}, 'g1.2'),
						'boot_from_volume' => $self->TRUE,
						'root_disk' => {
							'size' => 30
						},
					},
					stackit => {
						'instance_type' => $self->for_scale({
							dev => 't2i.1',
							prod => 'g2i.2'
						}, 'g2i.1'),
						'boot_from_volume' => $self->TRUE,
						'root_disk' => {
							'size' => 30 # in gigabytes
						},
					},
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
				}
			),
		],
		'disk_types' => [
			# The local DB is the only persistent disk type needed
			$self->disk_type_definition('postgres',
				common => {
					disk_size => $self->for_scale({
						dev => gigabytes(32),
						prod => gigabytes(64)
					}, gigabytes(32))
				},
				cloud_properties_for_iaas => {
					'openstack|stackit' => {
						'type' => 'storage_premium_perf6',
					},
					aws => {
						'type' => 'gp3',
						'encrypted' => $self->TRUE,
					},
				},
			),
		],
	});

	$self->done($config);
}

1;

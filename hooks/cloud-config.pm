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
	$obj->check_minimum_genesis_version('3.1.0-rc.4');
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
						'openstack|stackit' => {
							'net_id' => $self->network_reference('id'),
							'security_groups' => $self->get_network_security_groups(),
						},
						'aws' => {
							'subnet' => $self->network_reference('id'),
							'security_groups' => $self->get_network_security_groups(),
						},
					},
				},
			)
		],
		'vm_types' => [
			$self->generic_vm_type('apiserver'),
			$self->generic_vm_type('scalingengine'),
			$self->generic_vm_type('scheduler'),
			$self->generic_vm_type('operator'),
			$self->generic_vm_type('eventgenerator'),
			$self->generic_vm_type('metricsforwarder'),
		],
		'disk_types' => [
			# The local DB is the only persistent disk type needed
			$self->generic_disk_type('postgres'),
		],
	});

	$self->done($config);
}

# All the vms use the same basic vm type, so keep it DRY.
# TODO: Allow arguments to customize the vm type, which keeps it clear what
# values differ
sub generic_vm_type {
	my ($self, $name) = @_;
	return $self->{__generic_vm_type} //= $self->vm_type_definition($name,
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
	);
}

sub generic_disk_type {
	my ($self,$name) = @_;
	return $self->{__generic_disk_type} //= $self->disk_type_definition($name,
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
	);
}

1;

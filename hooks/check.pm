package Genesis::Hook::AppAutoscaler::Check;


use v5.20;
use warnings; # Genesis min perl version is 5.20
use Genesis qw/info error bail new_enough/;
# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'./.genesis/lib'}

use parent qw(Genesis::Hook::Check);
sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0-rc.20');
	return $obj;
}

sub perform {
	my ($self) = @_;

  my $ok = 1;
	# Run all component checks
  $ok = 0 unless $self->check_cf_version_compatibility();
	$ok = 0 unless $self->check_cloud_config();
	$ok = 0 unless $self->check_runtime_config();

	return $self->done($ok);
}

sub check_cloud_config {
	my ($self) = @_;

	# For now, we're just going to check that there is a cloud config, but
	# ideally we should check that the cloud config contains all the required
	# properties for this deployment.
	#
	# DISCUSS: Since we now generate the cloud config from the kit, and genesis
	# is responsible for uploading it at deployment time, do we even need to
	# check for the cloud config or validate its contents?

  $self->start_check('cloud-config');
  return $self->check_result('cloud-config','skipped','OCFP env manages its own cloud-config') if $self->is_ocfp;
  return $self->check_result('cloud-config','failed', 'no cloud config found') unless  $self->env->has_config('cloud');
  return $self->check_result('cloud-config');
}

sub check_runtime_config {
	my ($self) = @_;

  $self->start_check('runtime-config');

  return $self->check_result('runtime-config','failed', 'no runtime config found') unless $self->env->has_config('runtime');

  $self->has_entry('runtime-config','job','bosh-dns');

  #FIXME: Need to ensure the job is for the target stemcell os
  return $self->check_result('runtime-config');
}

# TODO: How to handle not yet deployed?
sub check_cf_version_compatibility {
  my ($self) = @_;

  $self->start_check('version upgrade compatibility');
 
  # Get CF deployment exodus data
  my $cf_env = $self->env->lookup('params.cf_deployment_env', $self->env->name);
  my $cf_type = $self->env->lookup('params.cf_deployment_type', 'cf');
  my $cf_exodus = $self->env->exodus_lookup('.', {}, "$cf_env/$cf_type");

  # Get CF kit version
  my $cf_kit_version = $cf_exodus->{kit_version};
  bail("#R{[ERROR]} Could not determine kit version with associated CF deployment")
    unless $cf_kit_version;

  # Check if CF kit version is new enough
  if (new_enough($cf_kit_version, "2.5.2")) {
    info("  target cf kit version [#G{OK}]");
  } else {
    bail("\n#R{[ERROR]} This version of autoscaler kit requires CF Kit 2.5.2 or greater to be deployed as its target CF.\n");
  }
  return 1;
}


1;

# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:

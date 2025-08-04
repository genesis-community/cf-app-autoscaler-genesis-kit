package Genesis::Hook::Check::AppAutoscaler;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::Check);

use Genesis qw/bail info new_enough/;

# init - Initialize the hook {{{
sub init {
	my ($class, %ops) = @_;
	my $obj = $class->SUPER::init(%ops);
	$obj->check_minimum_genesis_version('3.1.0');
	return $obj;
}

# }}}

# perform - Main hook execution {{{
sub perform {
	my ($self) = @_;
	my $ok = 1;

	# Cloud Config checks
	$ok = 0 unless $self->check_cloud_config();

	# Runtime Config checks
	$ok = 0 unless $self->check_runtime_config();

	# CF kit version compatibility check
	$ok = 0 unless $self->check_cf_kit_version();

	# Environment parameter checks
	$ok = 0 unless $self->check_environment();

	return $self->done($ok);
}

# }}}

# check_cloud_config - Validate cloud config requirements {{{
sub check_cloud_config {
	my ($self) = @_;

	$self->start_check('cloud-config');

	return $self->check_result('cloud-config', 'skipped', 'no cloud config specified')
		unless $ENV{GENESIS_CLOUD_CONFIG};

	if ($self->want_feature('ocfp')) {
		my $cf_env = $self->env->lookup('params.cf_deployment_env') // $self->env->name;
		my @jobs = qw(apiserver scalingengine scheduler operator eventgenerator metricsforwarder);

		# Check VM types for each job
		for my $job (@jobs) {
			my $vm_type_key = "${cf_env}.$ENV{GENESIS_TYPE}.vm-${job}";
			my $vm_type = $self->env->lookup("params.vm_type") // $vm_type_key;
			$self->check_cloud_config_type('vm_type', $vm_type);
		}

		# Check network and disk type
		my $network_key = "${cf_env}.$ENV{GENESIS_TYPE}.net-autoscaler";
		my $network = $self->env->lookup("params.network") // $network_key;
		$self->check_cloud_config_type('network', $network);

		my $disk_type_key = "${cf_env}.$ENV{GENESIS_TYPE}.disk-postgres";
		my $disk_type = $self->env->lookup("params.disk_pool") // $disk_type_key;
		$self->check_cloud_config_type('disk_type', $disk_type);

	} else {
		# Legacy hard-coded checks
		for my $vm_type (qw(minimal small)) {
			$self->check_cloud_config_type('vm_type', $vm_type);
		}
	}

	return $self->check_result('cloud-config');
}

# }}}

# check_runtime_config - Validate runtime config requirements {{{
sub check_runtime_config {
	my ($self) = @_;

	$self->start_check('runtime-config');

	# Check for BOSH DNS addon
	$self->check_runtime_config_addon('bosh-dns');

	return $self->check_result('runtime-config');
}

# }}}

# check_cf_kit_version - Validate CF kit version compatibility {{{
sub check_cf_kit_version {
	my ($self) = @_;

	$self->start_check('target cf kit version');

	my $cf_env = $self->env->lookup('params.cf_deployment_env') // $self->env->name;
	my $cf_type = $self->env->lookup('params.cf_deployment_type') // 'cf';

	my $cf_exodus;
	eval {
		$cf_exodus = $self->env->top->exodus_for("$cf_env/$cf_type");
	};
	return $self->check_result('target cf kit version', 'failed',
		'Could not determine exodus data for associated CF deployment')
		unless $cf_exodus;

	my $cf_kit_version = $cf_exodus->{kit_version};
	return $self->check_result('target cf kit version', 'failed',
		'Could not determine kit version with associated CF deployment')
		unless $cf_kit_version;

	return $self->check_result('target cf kit version', 'failed',
		'This version of autoscaler kit requires CF Kit 3.0.0 or greater')
		unless new_enough($cf_kit_version, '3.0.0');

	return $self->check_result('target cf kit version');
}

# }}}

# check_environment - Validate environment parameters {{{
sub check_environment {
	my ($self) = @_;

	$self->start_check('environment');

	# Currently no environment parameter checks
	# Add parameter validation here as needed

	return $self->check_result('environment');
}

# }}}

1;
# vim: ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1 nu

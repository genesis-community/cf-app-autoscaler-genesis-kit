# CF App Autoscaler Addon Mixin
# This file provides common methods for CF App Autoscaler addon hooks
# Include with: do dirname(__FILE__) . '/_lib_addon.pm';
#
# Note: This file relies on the importing module to have the necessary
# 'use' statements for Genesis, Genesis::UI, etc.

# Override init to add version check
sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->check_minimum_genesis_version('3.1.0');
	return $obj;
}

# Common CF login method for all CF App Autoscaler addons
sub cf_login {
	my ($self) = @_;

	# Get CF deployment info from primary exodus
	my $cf_deployment_env = $self->exodus_data->{cf_deployment_env}
		or bail("Required %C{%s} value not found in #M{%s} environment's exodus data", 'cf_deployment_env', $self->env->name);
	my $cf_deployment_type = $self->exodus_data->{cf_deployment_type}
		or bail("Required %C{%s} value not found in #M{%s} environment's exodus data", 'cf_deployment_type', $self->env->name);

	# Get all CF credentials from the CF deployment's exodus data
	my $cf_target = "${cf_deployment_env}/${cf_deployment_type}";
	my $cf_exodus = $self->env->exodus_lookup('.', {}, $cf_target);

	my $system_domain = $cf_exodus->{system_domain}
		or bail("Required %C{%s} value not found in #M{%s} environment's exodus data", 'system_domain', $cf_target);
	my $username = $cf_exodus->{admin_username}
		or bail("Required %C{%s} value not found in #M{%s} environment's exodus data", 'admin_username', $cf_target);
	my $password = $cf_exodus->{admin_password}
		or bail("Required %C{%s} value not found in #M{%s} environment's exodus data", 'admin_password', $cf_target);

	my $api_url = "https://api.$system_domain";

	# CF login
	info("Connecting to CF API at %s", $api_url);
	run({
		interactive => 1,
		onfailure => "Failed to log in to CF API at $api_url",
	}, 'cf', 'api', $api_url, '--skip-ssl-validation');

	run({
		interactive => 1,
		onfailure => "Failed to log in to CF with username '$username'",
	}, 'cf', 'auth', $username, $password);

	# Check for cf-targets plugin
	my ($out, $rc) = run('cf plugins | grep -q \'^cf-targets\'');
	if ($rc == 0) {
		run({interactive => 1}, 'cf', 'save-target', '-f', $cf_deployment_env);
	} else {
		info("#Y{The cf-targets plugin does not seem to be installed} -- cannot save current target");
	}

	return scalar run({interactive => 1, passfail => 1},'cf', 'target');
}

# Common method to get service broker credentials
sub get_service_broker_credentials {
	my ($self) = @_;

	my @needed = qw/service_broker_username service_broker_password service_broker_domain/;
	my @sb_data = $self->exodus_data(@needed);
	my @missing = map {$needed[$_]} grep {!defined $sb_data[$_]} 0 .. $#needed;
	bail(
		"Required service broker credentials not found in exodus data: %s",
		sentence_join(', ', @missing)
	) if @missing;

	return ($sb_data[0], $sb_data[1], 'https://'.$sb_data[2]);
}

1;

# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:

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

	# Get CF deployment info from primary exodus
	my $cf_deployment_env = $obj->exodus_data->{cf_deployment_env} # Getting key from structure
		or bail("Required %C{%s} value not found in #M{%s} environment's exodus data", 'cf_deployment_env', $obj->env->name);
	my $cf_deployment_type = $obj->exodus_data->{cf_deployment_type}
		or bail("Required %C{%s} value not found in #M{%s} environment's exodus data", 'cf_deployment_type', $obj->env->name);

	# Get all CF credentials from the CF deployment's exodus data
  $obj->{cf_target} = "${cf_deployment_env}/${cf_deployment_type}";
	$obj->{cf_exodus} = $obj->env->exodus_lookup('.', {}, $obj->{cf_target});

	return $obj;
}

# Common CF login method for all CF App Autoscaler addons
sub cf_login {
	my ($self) = @_;

	my $system_domain = $self->{cf_exodus}{system_domain}
		or bail("Required %C{%s} value not found in #M{%s} environment's exodus data", 'system_domain', $self->{cf_target});
	my $username = $self->{cf_exodus}{admin_username}
		or bail("Required %C{%s} value not found in #M{%s} environment's exodus data", 'admin_username', $self->{cf_target});
	my $password = $self->{cf_exodus}{admin_password}
		or bail("Required %C{%s} value not found in #M{%s} environment's exodus data", 'admin_password', $self->{cf_target});

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

	$self->exodus_data(".", undef, "");
	my $app_autoscaler_client = $self->{cf_exodus}{app_autoscaler_client};
	my $app_autoscaler_secret = $self->{cf_exodus}{app_autoscaler_secret};
	my $autoscaler_api_domain = $self->exodus_data("autoscaler_api_domain"); # exodus_data is cached, convenience function call method

	bail(
		"Required service broker credentials not found in exodus data: cf/app_autoscaler_client,app_autoscaler_secret and/or cf-app-autoscaler/autoscaler_api_domain"
	) unless ( $app_autoscaler_secret && $app_autoscaler_client && $autoscaler_api_domain );

	return ( $app_autoscaler_client, $app_autoscaler_secret, 'https://'.$autoscaler_api_domain );
}

1;

# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:

package Genesis::Hook::Addon::CFAppAutoscaler::ConfigAutoscaler;

use v5.20;
use warnings;

# Only needed for development
BEGIN { push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME} . '/.genesis/lib' }

use parent qw(Genesis::Hook::Addon);
use Genesis qw/info run bail mkdir_or_fail save_to_json_file/;
use Genesis::Term qw/wrap colored_block terminal_width/;
use Genesis::UI qw/prompt_for_boolean prompt_for_line new_prompt_for_choice/;
use JSON::PP qw/encode_json/;

# Include common methods from mixin
BEGIN {
	require File::Basename;
	my $mixin_file = File::Basename::dirname(__FILE__) . '/_lib_addon.pm';
	do $mixin_file or die "Failed to include addon mixin $mixin_file: $!";
}

sub cmd_details {
	return "Configures autoscaling for a Cloud Foundry app of your choosing.";
}

# Print a colorized header block with wrapping and margins
sub _print_header {
	# 2 space margins on left and right, one liine top and bottom
	info("\n%s",
		colored_block(wrap("\n$_[0]\n", terminal_width - 2, undef, 2),$_[1]//'Wk')
	);
}

# Target a new org/space interactively
sub _target_org_space {
	my ($self) = @_;
	my $run_opts = {
		interactive => 1,
		onfailure => "Failed to execute 'cf' command successfully",
	};

	_print_header("These are the organizations defined in your Cloud Foundry deployment");

	run($run_opts,'cf', 'orgs');
	my $org_name = prompt_for_line('Type the organization name your application resides on');

	run($run_opts,'cf', 'target', '-o', $org_name);

	_print_header("These are the spaces defined for your #bu{$org_name} organization in your Cloud Foundry deployment");

	run($run_opts,'cf', 'spaces');
	my $space_name = prompt_for_line('Type the space name your application resides on');

	run($run_opts,'cf', 'target', '-o', $org_name, '-s', $space_name);

	return ($org_name, $space_name);
}

sub perform {
	my ($self) = @_;

	my $run_opts = {
		interactive => 1,
		onfailure => "Failed to execute 'cf' command successfully",
	};

	# FIXME: we should be using cf_login() from the mixin, but it doesn't do
	# the cf-targets stuff we need here

	# Get CF deployment info from primary exodus
	my $cf_deployment_env = $self->exodus_data->{cf_deployment_env}
		or bail("Required #C{%s} value not found in #M{%s} environment's exodus data", 'cf_deployment_env', $self->env->name);
	my $cf_deployment_type = $self->exodus_data->{cf_deployment_type}
		or bail("Required #C{%s} value not found in #M{%s} environment's exodus data", 'cf_deployment_type', $self->env->name);


	# Check current target
	my ($current_target, $rc) = run('cf target');
	my ($org_name, $space_name);

	if ($rc != 0 || $current_target =~ /FAILED/) {
		# Need to login first - get all CF credentials from the CF deployment's exodus data
		my $cf_target = "${cf_deployment_env}/${cf_deployment_type}";
		my $cf_exodus = $self->env->exodus_lookup('.', {}, $cf_target);

		my $system_domain = $cf_exodus->{system_domain}
			or bail("Required #C{%s} value not found in #M{%s} environment's exodus data", 'system_domain', $cf_target);
		my $username = $cf_exodus->{admin_username}
			or bail("Required #C{%s} value not found in #M{%s} environment's exodus data", 'admin_username', $cf_target);
		my $password = $cf_exodus->{admin_password}
			or bail("Required #C{%s} value not found in #M{%s} environment's exodus data", 'admin_password', $cf_target);

		my $api_url = "https://api.$system_domain";

		# CF login
		info("Connecting to CF API at %s", $api_url);
		run($run_opts,'cf', 'api', $api_url, '--skip-ssl-validation');
		run($run_opts,'cf', 'auth', $username, $password);

		my ($plugins_output) = run('cf', 'plugins');
		if ($plugins_output =~ /cf-targets/) {
			run($run_opts, 'cf', 'save-target', '-f', $cf_deployment_env);
		} else {
			# TODO: do we want to: warning("The cf-targets plugin does not seem to be installed -- cannot save current target");
		}


		($org_name, $space_name) = $self->_target_org_space();
	}

	# Check if already targeted to org/space
	my ($new_target) = run({%$run_opts,interactive => 0}, 'cf', 'target');
	if ($new_target =~ /No org or space targeted/) {
		($org_name, $space_name) = $self->_target_org_space();
		($new_target) = run($run_opts, 'cf', 'target');
	}

	# Parse current target if not already set
	unless ($org_name && $space_name) {
		($org_name) = $new_target =~ /org:\s*(\S+)/;
		($space_name) = $new_target =~ /space:\s*(\S+)/;
	}

	# Ask if user wants to target different org/space
	my $target_new = prompt_for_boolean(
		"You have targeted organization #bu{$org_name} and space #bu{$space_name}.\n" .
		"Would you like to connect to another org/space?", 0
	);

	if ($target_new) {
		($org_name, $space_name) = $self->_target_org_space();
		($new_target) = run('cf target');

		# Re-parse target
		my @target_parts = split(/\s+/, $new_target);
		for my $i (0..$#target_parts) {
			if ($target_parts[$i] eq 'org:') {
				$org_name = $target_parts[$i+1] if $i+1 <= $#target_parts;
			}
			if ($target_parts[$i] eq 'space:') {
				$space_name = $target_parts[$i+1] if $i+1 <= $#target_parts;
			}
		}
	}

	# Show applications
	_print_header("These are the applications running in your Cloud Foundry deployment");

	run($run_opts, 'cf', 'apps');
	my $app_name = prompt_for_line('Type the application name you would like to configure autoscaling for');

	my $app_min = prompt_for_line(undef, 'Type the minimum number of instances running at all times', '2', qr/^\d+$/);
	my $app_max = prompt_for_line(undef, 'Type the maximum number of instances running at all times', '5', qr/^\d+$/);

	my $app_metric_type = new_prompt_for_choice(
		header => 'Choose the metric type used for autoscaling',
		choices => [
			{ label => 'CPU (%)',                     value => 'cpu' },
			{ label => 'Memory Used (MB)',            value => 'memory_used' },
			{ label => 'Memory Used (%)',             value => 'memory_util' },
			{ label => 'Response Time',               value => 'response_time' },
			{ label => 'Throughput (requests per second)', value => 'throughput' }
		],
		default => 'response_time',
	);

	my $app_metric_up =   prompt_for_line(undef, 'Type the threshold value at which your instances will scale up',  '10', qr/^\d+$/);
	my $app_metric_down = prompt_for_line(undef, 'Type the threshold value at which your instances will scale down', '1', qr/^\d+$/);

	# Create policies directory
	my $policies_dir = "$ENV{GENESIS_ROOT}/policies";
	mkdir_or_fail($policies_dir) unless -d $policies_dir;

	# Create policy JSON
	my $policy_filename = "$policies_dir/$org_name-$space_name-$app_name-as-policy.json";
	my $policy_data = {
		instance_min_count => int($app_min),
		instance_max_count => int($app_max),
		scaling_rules => [
			{
				metric_type => $app_metric_type,
				breach_duration_secs => 60,
				threshold => int($app_metric_down),
				operator => "<=",
				cool_down_secs => 60,
				adjustment => "-1"
			},
			{
				metric_type => $app_metric_type,
				breach_duration_secs => 60,
				threshold => int($app_metric_up),
				operator => ">",
				cool_down_secs => 60,
				adjustment => "+1"
			}
		]
	};

	my $create_policy = 1;
	if (-f $policy_filename) {
		$create_policy = prompt_for_boolean(
			"The policy file already exists. Overwrite it? Type #bu{no} to use the one under policies/$org_name-$space_name-$app_name-as-policy.json", 1
		);
	}

	save_to_json_file($policy_data, $policy_filename) if ($create_policy);

	my $service_name = $self->exodus_data("service_name");

	# Get first autoscaler service
	my ($services_output) = run({%$run_opts, interactive =>0}, 'cf', 'services');
	my ($first_as_service_name) = $services_output =~ /^(\S+)\s+$service_name/m;
	$first_as_service_name //= '';

	_print_header("These are the services currently running in your Cloud Foundry Deployment");
	info($services_output);
	my $as_service_name = prompt_for_line('Type the autoscaler service name you would like to use', $first_as_service_name);

	# Check if app is already bound to autoscaling service
	my ($policy_output) = run({interactive => 0 },"cf", "autoscaling-policy","$app_name");
	if ($policy_output =~ /No AutoScaler api endpoint set/ ) {
	  my $autoscaling_api_url_domain = $self->exodus_data("autoscaler_api_domain");
	  my $autoscaling_api_url = "https://$autoscaling_api_url_domain";
	  info("Setting Autoscaler API to %s", $autoscaling_api_url);

	  my ($api_set_output) = run ({ interactive => 0}, "cf", "autoscaling-api", $autoscaling_api_url);
          if ($api_set_output =~ /FAILED/) {
	    bail ("Failed to set app-autoscaler domain:\n%s", $api_set_output);
	  }
	  ($policy_output) = run({interactive => 0 },"cf", "autoscaling-policy","$app_name");
	}

	if ($policy_output =~ /The application is not bound to Auto-Scaling service/) {
		run($run_opts, 'cf', 'bind-service', $app_name, $as_service_name, '-c', $policy_filename);
	} else {
		my $policy_reapply = prompt_for_boolean(
			"The application is already bound to an Auto-Scaling service. Re-apply it?", 0
		);
		if ($policy_reapply) {
			run($run_opts, 'cf', 'aasp', $app_name, $policy_filename);
		} else {
			return $self->done(0);
		}
	}

	return $self->done(1);
}

1;

# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:

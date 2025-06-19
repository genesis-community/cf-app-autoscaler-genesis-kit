package Genesis::Hook::Addon::AppAutoscaler::ConfigAutoscaler;

use v5.20;
use warnings;
use File::Path qw(make_path);

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::Addon);
use Genesis qw/info run mkfile_or_fail/;
use Genesis::UI qw/prompt_for prompt_for_boolean/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub cmd_details {
  return
  "Configures autoscaling for a Cloudfoundry app of your choosing.\n";
}

sub perform {
  my ($self) = @_;

  # Get terminal formatting
  my $bold = `tput bold`;
  my $normal = `tput sgr0`;

  # Check if we're already logged in
  my $current_target = eval { run("cf target") } || "";

  if ($current_target =~ /FAILED/ || $current_target =~ /No org or space targeted/) {
    $self->cf_login();
    $self->target_new_org_space();
  } else {
    my $current_org = (split(/\s+/, $current_target))[9];
    my $current_space = (split(/\s+/, $current_target))[11];

    my $target_new;
    prompt_for_boolean(
      "You have targeted organization ${bold}$current_org${normal} and space ${bold}$current_space${normal}.\n".
      "Would you like to connect to another org/space?",
      \$target_new
    );

    if ($target_new) {
      $self->target_new_org_space();
      $current_target = run("cf target");
      $current_org = (split(/\s+/, $current_target))[9];
      $current_space = (split(/\s+/, $current_target))[11];
    }
  }

  # Get the current org and space
  my $new_target = run("cf target");
  my $org_name = (split(/\s+/, $new_target))[9];
  my $space_name = (split(/\s+/, $new_target))[11];

  info("\n%s\n", "=" x 90);
  info("These are the applications running in your Cloudfoundry deployment\n");
  info("%s\n", "=" x 90);

  # TODO: Check the return values of run command to handle error cases.
  run("cf apps");

  my $app_name;
  prompt_for('app_name', 'line',
    'Type the application name you would like to configure autoscaling for',
    \$app_name);

  my $app_min;
  prompt_for('app_min', 'line', '--default', "2", '--validation', '/^\d+$/',
    'Type the minimum number of instances running at all times',
    \$app_min);

  my $app_max;
  prompt_for('app_max', 'line', '--default', "5", '--validation', '/^\d+$/',
    'Type the maximum number of instances running at all times',
    \$app_max);

  my $app_metric_type;
  prompt_for('app_metric_type', 'select',
    'Choose the metric type used for autoscaling',
    '-o', '[cpu]             CPU (%)',
    '-o', '[memory_used]     Memory Used (MB)',
    '-o', '[memory_util]     Memory Used (%)',
    '-o', '[response_time]   Response Time',
    '-o', '[throughput]      Throughput (requests per second)',
    \$app_metric_type);

  my $app_metric_up;
  prompt_for(
    'app_metric_up',
    'line',
    '--default', "10",
    '--validation', '/^\d+$/',
    'Type the threshold value at which your instances will scale up',
    \$app_metric_up
  );

  my $app_metric_down;
  prompt_for(
    'app_metric_down',
    'line',
    '--default', "1",
    '--validation', '/^\d+$/',
    'Type the threshold value at which your instances will scale down',
    \$app_metric_down
  );

  # TODO: Genesis must have a method instead of using the env var
  # Create policies directory
  make_path("$ENV{GENESIS_ROOT}/policies");

  my $policy_file = "$ENV{GENESIS_ROOT}/policies/$org_name-$space_name-$app_name-as-policy.json";
  my $policy_content = <<"EOF";
{
    "instance_min_count": $app_min,
    "instance_max_count": $app_max,
    "scaling_rules": [
        {
            "metric_type": "$app_metric_type",
            "breach_duration_secs": 60,
            "threshold": $app_metric_down,
            "operator": "<=",
            "cool_down_secs": 60,
            "adjustment": "-1"
        },
        {
            "metric_type": "cpu",
            "breach_duration_secs": 60,
            "threshold": $app_metric_up,
            "operator": ">",
            "cool_down_secs": 60,
            "adjustment": "+1"
        }
    ]
}
EOF

  # Check if policy file already exists
  if (-f $policy_file) {
    my $policy_overwrite;
    prompt_for_boolean(
      "The policy file aleady exists. Overwrite it? Type ${bold}no${normal} to use the one under policies/$org_name-$space_name-$app_name-as-policy.json",
      \$policy_overwrite
    );

    if (!$policy_overwrite) {
      # Use existing file
    } else {
      mkfile_or_fail($policy_file, $policy_content);
    }
  } else {
    mkfile_or_fail($policy_file, $policy_content);
  }

  # Get autoscaler service
  my ($first_as_service_name) = run("cf services | grep autoscaler | awk '{print \$1}'");
  chomp $first_as_service_name;

  info("\n%s\n", "=" x 90);
  info("These are the services currently running in your CloudFoundry Deployment\n");
  info("%s\n", "=" x 90);

  run("cf services");

  my $as_service_name;
  prompt_for('as_service_name', 'line', '--default', $first_as_service_name,
    'Type the autoscaler service name you would like to use',
    \$as_service_name);

  # Check if app is already bound to autoscaler
  my ($out, $rc) = run(
    "cf autoscaling-policy $app_name | grep \"The application is not bound to Auto-Scaling service\""
  );
  if ($rc == 0) {
    # App is not bound to autoscaler
  # TODO: Check the return values of run command to handle error cases.
    run("cf bind-service $app_name $as_service_name -c $policy_file");
  } else {
    # App is already bound to autoscaler
    my $policy_reapply;
    prompt_for_boolean(
      "The application is already bound to an Auto-Scaling service. Re-apply it?",
      \$policy_reapply
    );

    if ($policy_reapply) {
  # TODO: Check the return values of run command to handle error cases.
      run("cf aasp $app_name $policy_file");
    }
  }

  return $self->done(1);
}

sub target_new_org_space {
  my ($self) = @_;

  info("\n%s\n", "=" x 90);
  info("These are the organizations defined in your Cloudfoundry deployment\n");
  info("%s\n", "=" x 90);

  # TODO: Check for error in run command
  run("cf orgs");

  my $org_name;
  prompt_for(
    'org_name',
    'line',
    'Type the organization name your application resides on',
    \$org_name
  );

  # TODO: Check for and handle error in run command
  run("cf target -o $org_name");

  info("\n%s\n", "=" x 90);
  info("These are the spaces defined for your #G{$org_name} orgnization in your Cloudfoundry deployment\n");
  info("%s\n", "=" x 90);

  # TODO: Check for and handle error in run command
  run("cf spaces");

  my $space_name;
  prompt_for(
    'space_name',
    'line',
    'Type the space name your application resides on',
    \$space_name
  );

  # TODO: Check for and handle error in run command
  run("cf target -o $org_name -s $space_name");

  return;
}

sub cf_login {
  my ($self) = @_;

  my $cf_deployment_env = $self->env->exodus_lookup('cf_deployment_env');
  my $cf_deployment_type = $self->env->exodus_lookup('cf_deployment_type');
  my $cf_exodus = "$ENV{GENESIS_EXODUS_MOUNT}$cf_deployment_env/$cf_deployment_type";

  my $system_domain = $self->vault->get("$cf_exodus:system_domain");
  my $api_url = "https://api.$system_domain";
  my $username = $self->vault->get("$cf_exodus:admin_username");
  my $password = $self->vault->get("$cf_exodus:admin_password");

  # TODO: Check for and handle error in run command
  run("cf api \"$api_url\" --skip-ssl-validation");
  run("cf auth \"$username\" \"$password\"");

  my ($out, $rc) = run("cf plugins | grep -q '^cf-targets'");
  if ($rc != 0) {
    info("#Y{The cf-targets plugin does not seem to be installed} -- cannot save current target");
  } else {
    run("cf save-target -f \"$cf_deployment_env\"");
  }

  run("cf target");

  return 1;
}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:

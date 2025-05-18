#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::New::AppAutoscaler v4.0.0;

use strict;
use warnings;
use v5.20;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

# Parent class inheritance
use parent qw(Genesis::Hook);

# Import required functions
use Genesis qw/info bail run/;
use Genesis::UI qw/prompt_for prompt_for_boolean/;

sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->{features} = ['(( append ))'];
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub exodus_prompt {
  my ($self, $field, $exodus_data) = @_;

  if (!$exodus_data || $exodus_data eq "{}") {
    return "\n#g{(Leave blank to use CF metadata for $field - }#Yi{not currently available}#g{)}";
  } else {
    my $value;
    eval {
      $value = run("jq -re '.$field' <<< '$exodus_data'");
      chomp $value;
    };
    if ($@) {
      return "\n#g{(Leave blank to use CF metadata for $field - }#Ri{not set by last deployment}#g{)}";
    } else {
      return "\n#g{(Leave blank to use }#m{$field}#g{ cf metadata of '}#G{$value}#g{')}";
    }
  }
}

sub perform {
  my ($self) = @_;

  info("#Cu{Cloud Foundry Host:}");

  my $cf_deployment;
  prompt_for('cf_deployment', 'line',
    'What is the name of the Cloud Foundry environment?',
    "--default", $ENV{GENESIS_ENVIRONMENT}, \$cf_deployment);

  my $cf_deployment_type;
  prompt_for('cf_deployment_type', 'line',
    'What is deployment type of the Cloud Foundry enviornment?',
    "--default", 'cf', \$cf_deployment_type);

  info("\n#Yi{Fetching metadata from CF deployment }#Ci{$cf_deployment-$cf_deployment_type}#Yi{...}");
  my $exodus_data = $self->env->exodus_lookup('.', '{}', "$cf_deployment/$cf_deployment_type");

  if ($exodus_data eq "{}") {
    info(
      "\n#Y{[WARNING]} Metadata not available for CF deployment:\n\t#C{$cf_deployment-$cf_deployment_type}.".
      "\n\tCannot show values that will be used if not overwritten for the following parameters.\n"
    );
  }

  my $system_domain;
  prompt_for('system_domain', 'line', '--default', '',
    "What is the system domain for the host Cloud Foundry?".$self->exodus_prompt('system_domain', $exodus_data),
    \$system_domain);

  my $network;
  prompt_for('network', 'line', '--default', '',
    "What network do you want use (core network on the host Cloud Foundry recommended)?".
    $self->exodus_prompt('core_network', $exodus_data),
    \$network);

  info("\n#Cu{Database Configuration:}");

  my $db_type;
  prompt_for('db_type', 'select',
    'What database type will be used for storing App Autoscaler data?',
    '-o', "[postgres] PostgreSQL",
    '-o', "[mysql] MySQL",
    '--default', 'postgres',
    \$db_type);

  push @{$self->{features}}, $db_type;

  my $db_location;
  prompt_for('db_location', 'select',
    'Where will this database be located?',
    '-o', '[external-db] Existing external database',
    '-o', '[] Create an internal database',
    '--default', 'external-db',
    \$db_location);

  my ($db_host, $db_port, $db_name, $db_user, $use_tls);
  if ($db_location eq 'external-db') {
    push @{$self->{features}}, $db_location;

    prompt_for('db_host', 'line',
      "What is the host name for the external $db_type database?",
      \$db_host);

    my $default_db_port = ($db_type eq 'mysql') ? 3306 : 5432;
    prompt_for('db_port', 'line', '--default', $default_db_port,
      'What is the host port?',
      \$db_port);

    my $default_db_name = 'autoscaler';
    prompt_for('db_name', 'line', '--default', $default_db_name,
      'What is the name of the existing database to be used?',
      \$db_name);

    prompt_for('db_user', 'line', '--default', $default_db_name,
      "What is the name of the user for accessing the '$db_name' database?",
      \$db_user);

    info("\n");

    my $db_password;
    prompt_for('external_db:password', 'secret-line',
      "What is the password for the '$db_user' user?",
      \$db_password);

    my $db_ca;
    prompt_for('external_db:tls_ca', 'secret-block',
      "What is the TLS CA certificate for the external database (Leave blank to ignore)?",
      \$db_ca);

    info("\n\n#Ci{Storing secrets in Credhub...}\n");
    run("safe set \"$ENV{GENESIS_SECRETS_BASE}autoscaler_database_password\" \"$db_password\"");

    if ($db_ca && $db_ca ne "") {
      $use_tls = 1;
      run("safe set \"$ENV{GENESIS_SECRETS_BASE}autoscaler_database_tls_ca\" \"$db_ca\"");
    }

    info("\n#G{done.}\n");
  }

  # Create environment YAML file
  my $yaml = "$ENV{GENESIS_ROOT}/$ENV{GENESIS_ENVIRONMENT}.yml";
  open my $fh, ">", $yaml or bail("Could not open $yaml for writing: $!");

  print $fh "---\n";
  print $fh "kit:\n";
  print $fh "  name:    $ENV{GENESIS_KIT_NAME}\n";
  print $fh "  version: $ENV{GENESIS_KIT_VERSION}\n";
  print $fh "  features:\n";
  foreach my $feature (@{$self->{features}}) {
    print $fh "    - $feature\n";
  }

  # Add genesis_config_block
  my ($out) = run("genesis_config_block");
  print $fh $out;

  # Add params if necessary
  my @params_lines;
  push @params_lines, "  cf_deployment_env:  $cf_deployment" if $cf_deployment;
  push @params_lines, "  cf_deployment_type: $cf_deployment_type" if $cf_deployment_type;
  push @params_lines, "  network:            $network" if $network;
  push @params_lines, "  cf_system_domain:   $system_domain" if $system_domain;

  if (@params_lines) {
    print $fh "params:\n";
    print $fh join("\n", @params_lines) . "\n";
  }

  # Add bosh variables if necessary
  if ($db_location eq 'external-db') {
    print $fh "\nbosh-variables:\n";
    print $fh "  database:\n";
    print $fh "    host:     $db_host\n";

    my $default_db_port = ($db_type eq 'mysql') ? 3306 : 5432;
    print $fh "    port:     $db_port\n" if $db_port != $default_db_port;

    my $default_db_name = 'autoscaler';
    print $fh "    name:     $db_name\n" if $db_name ne $default_db_name;
    print $fh "    username: $db_user\n" if $db_user ne $default_db_name;

    if (!$use_tls) {
      print $fh "    ssl_mode: require\n";
      print $fh "    tls:      {ca: \"\"}\n";
    }
  }

  close $fh;

  # Offer environment editor
  run({ interactive => 1 }, "offer_environment_editor");

  return $self->done(1);
}

1;


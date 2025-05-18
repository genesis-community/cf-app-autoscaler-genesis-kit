#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::AppAutoscaler::SetupCfPlugin v4.0.0;

use strict;
use warnings;
use v5.20;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::Addon);
use Genesis qw/info run/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub cmd_details {
  return
  "Adds the 'autoscaler' plugin to the cf cli. Supports the following options:\n".
  "[[  #y{-f}                >>Force installation of plugins, overwriting existing versions";
}

sub perform {
  my ($self) = @_;

  # Parse options according to the proper pattern
  my %options = $self->parse_options(['f']);

  $self->cf_login();

  info("\n\n#Wkiu{Attempting to install latest version of the CF-Community/app-autoscaler-plugin...}");

  # TODO: Check the return values of run command to handle error cases.
  my ($existing) = run("cf plugins --checksum | grep AutoScaler | tr -s ' ' | cut -d ' ' -f 2");
  chomp $existing;

  my $force = $options{f} ? "-f" : "";
  # TODO: Check the return values of run command to handle error cases.
  run("cf install-plugin -r CF-Community app-autoscaler-plugin $force");

  # TODO: Check the return values of run command to handle error cases.
  my ($updated) = run("cf plugins --checksum | grep AutoScaler | tr -s ' ' | cut -d ' ' -f 2");
  chomp $updated;

  if ($updated eq "") {
    info("\n");
    return $self->done(0);
  }

  if ($existing eq $updated) {
    info("No update - existing app-autoscaler-plugin remains at version $existing\n");
    return $self->done(1);
  }

  my $action = $existing ? "updated" : "installed";
  # TODO: Check the return values of run command to handle error cases.
  my ($header) = run("cf plugins | head -n3 | tail -n1");
  chomp $header;

  info("\n$header");
  # TODO: Check the return values of run command to handle error cases.
  run("echo \"$header\" | sed -e 's/[^ ] [^ ]/xxx/g' | sed -e 's/[^ ]/-/g'");
  run("cf plugins | grep AutoScaler");

  info(
    "\n#G{[OK]} Successfully $action CF-Community app-autoscaler-plugin.".
    "\n\tYou can run #c{cf uninstall-plugin AutoScaler} to remove it when no longer desired."
  );

  return $self->done(1);
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

  # TODO: Check the return values of run command to handle error cases.
  run("cf api \"$api_url\" --skip-ssl-validation");
  run("cf auth \"$username\" \"$password\"");

  my ($out, $rc) = run("cf plugins | grep -q '^cf-targets'");
  if ($rc != 0) {
    info("#Y{The cf-targets plugin does not seem to be installed} -- cannot save current target");
  } else {
    run("cf save-target -f \"$cf_deployment_env\"");
  }

  # TODO: Check the return values of run command to handle error cases.
  run("cf target");

  return 1;
}

1;

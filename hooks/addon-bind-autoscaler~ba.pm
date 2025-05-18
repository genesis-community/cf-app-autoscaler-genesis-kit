#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::AppAutoscaler::BindAutoscaler v4.0.0;

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
  "Binds the Autoscaler service broker to your deployed CF.\n";
}

sub perform {
  my ($self) = @_;

  $self->cf_login();

  my $username = $self->env->exodus_lookup('service_broker_username');
  my $password = $self->env->exodus_lookup('service_broker_password');
  my $domain = $self->env->exodus_lookup('service_broker_domain');
  my $url = "https://$domain";

  # TODO: Check the return values of run command to handle error cases.
  run("cf create-service-broker autoscaler \"$username\" \"$password\" \"$url\"");
  run("cf enable-service-access autoscaler");

  info("\n#G{[OK]} Successfully created the service broker.");

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

  run("cf target");

  return 1;
}

1;


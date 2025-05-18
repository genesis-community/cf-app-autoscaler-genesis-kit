#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::Check::AppAutoscaler v4.0.0;

use strict;
use warnings;
use v5.20;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

# Parent class inheritance
use parent qw(Genesis::Hook);

# Import required functions
use Genesis qw/info bail new_enough run/;

sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->{ok} = 1; # Start assuming all checks will pass
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;

  # Runtime config checks
  my $runtime_ok = 'yes';

  # Check for BOSH DNS
  my ($out, $rc) = run("rcq -e '.addons[] | .name | select(. == \"bosh-dns\")' &>/dev/null");
  if ($rc != 0) {
    $runtime_ok = 'no';
    info(
      "\n#R{Errors were found} in your runtime-config:".
      "\n\t- #R{BOSH DNS is not in the runtime-config, which is required. Refer to}".
      "\n\t\t#R{'genesis man $ENV{GENESIS_ENVIRONMENT}' for more info.}\n"
       );
  }

  # Output runtime config check results
  if ($runtime_ok eq "yes") {
    info("\truntime config [#G{OK}]");
  } else {
    info("\truntime config [#R{FAILED}]");
  }

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
    info("\n@error This version of autoscaler kit requires CF Kit 2.5.2 or greater to be deployed as its target CF.\n");
    return $self->done(0);
  }

  # Environment checks
  my $env_ok = 'yes';
  # Environment parameter checks can be added here if needed

  if ($env_ok eq "yes") {
    info("\tenvironment files [#G{OK}]");
  } else {
    info("\tenvironment files [#R{FAILED}]");
  }

  return $self->done($env_ok eq "yes" && $runtime_ok eq "yes");
}

1;

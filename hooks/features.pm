#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Features::AppAutoscaler v4.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Features);

use Genesis qw/bail/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;

  # Validate postgres and mysql features aren't both specified
  if (grep { $_ eq 'postgres' } @{$self->{features}} &&
      grep { $_ eq 'mysql' } @{$self->{features}}) {
    bail("#R{[ERROR]} Cannot specify both postgres and mysql features");
  }

  # Process each requested feature
  foreach my $feature (@{$self->{features}}) {
    if ($feature =~ /^(postgres|mysql|ocfp|external-db|override-subdomain)$/) {
      # These are primary supported features
      $self->add_feature($feature);
    }
    elsif ($feature eq 'cf-v1-support') {
      # Get CF deployment exodus data
      my $cf_env = $self->env->lookup('params.cf_deployment_env', $self->env->name);
      my $cf_type = $self->env->lookup('params.cf_deployment_type', 'cf');
      my $cf_exodus = $self->env->exodus_lookup('.', {}, "$cf_env/$cf_type");

      # Get CF kit version
      my $cf_kit_version = $cf_exodus->{kit_version};
      bail("#R{[ERROR]} Could not determine kit version with associated CF deployment")
        unless $cf_kit_version;

      if (new_enough($cf_kit_version, "2.3.0")) {
        bail("Feature #C{cf-v1-support} is no longer supported by cf kit v2.3.0 or later");
      } else {
        $self->add_feature($feature);
      }
    }
    elsif ($feature =~ /^operations\/.*/) {
      if (-f $self->env->kit->path("upstream/$feature.yml")) {
        $self->add_feature($feature);
      } else {
        bail("$self->env->kit->id does not support the $feature feature");
      }
    }
    elsif (-f $self->env->path("ops/$feature.yml")) {
      $self->add_feature($feature);

      # Copy the ops file to local_ops for blueprint
      my $dir = "local_ops/" . dirname($feature);
      run("mkdir -p \"$dir\"");
      run("cp \"$self->env->path('ops/$feature.yml')\" \"local_ops/$feature.yml\"");
    }
    else {
      bail("$self->env->kit->id does not support the #c{$feature} feature");
    }
  }

  # Add derived features based on selected features
  if ($self->has_feature('external-db')) {
    # Default to postgres if neither is specified
    if (!$self->has_feature('postgres') && !$self->has_feature('mysql')) {
      $self->add_feature('postgres');
    }
  }

  # Return the finalized list of features
  return $self->done($self->build_features_list());
}

1;

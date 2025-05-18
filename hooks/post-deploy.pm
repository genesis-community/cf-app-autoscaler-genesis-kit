#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::PostDeploy::AppAutoscaler v4.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

# Parent class inheritance
use parent qw(Genesis::Hook::PostDeploy);

# Import required functions
use Genesis qw/info/;

sub init {
  my ($class, %ops) = @_;
  my $self = $class->SUPER::init(%ops);
  $self->check_minimum_genesis_version('3.1.0-rc.20');
  return $self;
}

sub perform {
  my ($self) = @_;

  # Only display helpful information if the deployment was successful
  if ($self->deploy_successful) {
    info(
      "\n#M{$ENV{GENESIS_ENVIRONMENT}} App Autoscaler deployed!\n".
      "\nFor details about the deployment, run\n".
      "\t#G{$ENV{GENESIS_CALL_ENV} info}\n".
      "\nTo bind the autoscaler to your CF:\n".
      "\t#G{$ENV{GENESIS_CALL_ENV} do -- bind-autoscaler}\n".
      "\nTo add the autoscaler plugin to your CF CLI:\n".
      "\t#G{$ENV{GENESIS_CALL_ENV} do -- setup-cf-plugin}\n".
      "\nTo configure an application for autoscaling:\n".
      "\t#G{$ENV{GENESIS_CALL_ENV} do -- config-autoscaler}\n".
      "\n"
    );
  }

  # Call parent class methods if needed
  $self->SUPER::perform() if $self->can('SUPER::perform');

  # Mark the hook as completed successfully
  return $self->done(1);
}

1;

=head1 NAME

Genesis::Hook::PostDeploy::AppAutoscaler - Post-deployment hook for App Autoscaler Genesis Kit

=head1 DESCRIPTION

This module implements the post-deployment hook for the App Autoscaler Genesis Kit.
It displays helpful information to the user after a successful deployment.

=head1 METHODS

=head2 init(%options)

Initializes the hook with the given options.

=head2 perform()

Executes the post-deploy hook, displaying helpful information if the deployment was successful.

=head1 AUTHOR

Genesis Framework

=cut


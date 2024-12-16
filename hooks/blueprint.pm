#!/usr/bin/env perl
package Genesis::Hook::Blueprint::Bosh v3.0.4;

use strict;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Blueprint);

use Genesis qw/bail info warning error in_array new_enough save_to_yaml_file/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->{files} = [];
  $obj->check_minimum_genesis_version('3.1.0-rc.9');
  return $obj;
}

sub perform {
  my ($blueprint) = @_; # $blueprint is '$self'

# Get CF deployment exodus data
	my $cf_env  = $blueprint->env->lookup(['params.cf_deployment_env', 'genesis.env']);
	my $cf_type = $blueprint->env->lookup('params.cf_deployment_type', 'cf');
	bail(
		"Could not determine CF deployment environment"
	) unless $cf_env && $cf_type;

	my $cf_exodus = $blueprint->env->exodus_lookup('.', undef, "$cf_env/$cf_type");
	bail(
		"Failed to retrieve exodus data for $cf_env/$cf_type."
	) unless $cf_exodus and ref($cf_exodus) eq 'HASH' and keys %$cf_exodus;

	my $cf_kit_version = $cf_exodus->{kit_version};
	bail(
		"Could not determine kit version with associated CF deployment"
	) unless $cf_kit_version;
	bail(
		"CF kit version $cf_kit_version is not supported. Please upgrade to 2.5.0 or later."
	) unless new_enough($cf_kit_version, '2.5.0');

	# Base manifest files
	$blueprint->add_files(
		"overlay/app-autoscaler.yml", # This is the converted template from the upstream version
		"overlay/base.yml",
		"overlay/upstream_version.yml",
		"overlay/change_network_details.yml",
		"overlay/enable-nats-tls.yml", # This explicitly disables non-TLS nats
		"overlay/enable-log-cache.yml",
		"overlay/instance-identity-cert-from-cf.yml",
		"overlay/releases/app-autoscaler.yml"
	);

	if (exists($cf_exodus->{releases})) {
		save_to_yaml_file({releases => $cf_exodus->{releases}}, "$ENV{GENESIS_KIT_PATH}/overlay/cf-releases.dynamic.yml");
		$blueprint->add_files(
			"overlay/cf-releases.dynamic.yml",
		);

	}

	# Validate features
	my $invalid_features = [];
	for my $feature ($blueprint->features) {
		if ($feature =~ /(ocfp)/) {
			next; # always valid
		} elsif ($feature =~ /(external-db|postgres|mysql|deployment-name-in-domains|override-subdomain)/) {
			push @$invalid_features, "Cannot specify $feature and ocfp features together"
			  if $blueprint->want_feature('ocfp');
		} elsif ($feature =~ /(internal-db)/) {
			push @$invalid_features, "Cannot specify $feature without ocfp feature"
			  unless $blueprint->want_feature('ocfp');
		} elsif ($feature =~ /(cf-v1-support)/) {
			push @$invalid_features, "Feature $feature is no longer supported."
		} elsif ($feature =~ /operations\/(.*)/) {
			push @$invalid_features, "Feature $feature is not supported."
			  unless -f "upstream/operations/$1.yml";
		} else {
			push @$invalid_features, "Feature $feature is not supported."
			  unless -f "$ENV{GENESIS_ROOT}/ops/$feature.yml";
		}
	}
	push @$invalid_features, "Cannot specify both postgres and mysql features"
	  if $blueprint->want_feature('postgres') && $blueprint->want_feature('mysql');

	bail(
		"Invalid features specified: %s",
		join("\n  - ", '', @$invalid_features
	)) if @$invalid_features;

	if ($blueprint->want_feature('ocfp')) {
		# Validate OCFP-compatible features
		$blueprint->add_files(
			"ocfp/ocfp.yml",
		);
		if (! $blueprint->want_feature('internal-db')) {
			$blueprint->add_files(
				"upstream/operations/external-db.yml",
				"overlay/external_db/common.yml",
				"overlay/no-postgres.yml",
			);
		}
	} else {
		# Validate generic features
		if ($blueprint->want_feature('deployment-name-in-domains')) {
			$blueprint->add_files("overlay/deployment-name-in-domains.yml");
		}
		if ($blueprint->want_feature('external-db')) {
			$blueprint->add_files(
				"upstream/operations/external-db.yml",
				"overlay/external_db/common.yml",
				"overlay/no-postgres.yml",
			);
			if ($blueprint->want_feature('mysql')) {
				$blueprint->add_files("overlay/external_db/mysql.yml");
			} else {
				$blueprint->add_files("overlay/external_db/postgres.yml");
			}
		} elsif ($blueprint->want_feature('mysql')) {
			$blueprint->add_files(
				"upstream/operations/cf-mysql-db.yml", # Pretty sure this is very broken
				"overlay/no-postgres.yml",
			);
		}

	}

	for my $feature ($blueprint->features) {
		if ($feature =~ /^(ocfp|external-db|postgres|mysql|deployment-name-in-domains|internal-db)$/) {
			next; # already handled
		} elsif ($feature eq 'override-subdomain') {
			if ($blueprint->env->lookup('params.subdomain_prefix')) {
				$blueprint->add_files("overlay/change_subdomain.yml");
			} else {
				bail("Cannot use override-subdomain feature without specifying params.subdomain_prefix");
			}
		} elsif ($feature =~ /operations\/(.*)/) {
			$blueprint->add_files("upstream/operations/$1.yml");
		} else {
			$blueprint->add_files("$ENV{GENESIS_ROOT}/ops/$feature.yml");
		}
	}

	$blueprint->done();
}

1;

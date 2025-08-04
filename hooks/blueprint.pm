#!/usr/bin/env perl
package Genesis::Hook::Blueprint::CFAppAutoscaler v3.0.4;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::Blueprint);

use Genesis qw/bail info warning error new_enough by_semver load_yaml_file save_to_yaml_file sentence_join/;
use JSON::PP qw//;

# init - Initialize the hook {{{
sub init {
	my $class = shift;
	my $obj = $class->SUPER::init(@_);
	$obj->{files} = [];
	$obj->check_minimum_genesis_version('3.1.0');
	$obj->{upstream_dir} = 'upstream/';
	$obj->{upstream_pattern_match} = qr/^operations\/(.*)$/;
	return $obj;
}

# }}}
# perform - Main blueprint processing {{{
sub perform {
	my ($self) = @_;

	# Validate CF integration and get exodus data
	my $cf_info = $self->get_cf_integration_data();
	$self->{_cf_info} = $cf_info; # Store for processing methods

	# Check version compatibility between overlay and upstream
	$self->check_version_compatibility();

	# Version compatibility and upgrade checking
	$self->check_upgrade_compatibility();

	# Process the features
	if ($self->want_feature('ocfp')) {
		$self->validate_ocfp_features();
		return $self->process_ocfp_features();
	} else {
		$self->validate_classic_features();
		return $self->process_classic_features();
	}
}

# }}}

### Feature validation methods

# validate_classic_features - Validate features for classic (non-OCFP) deployments {{{
sub validate_classic_features {
	my ($self) = @_;

	# Custom validation
	my (@warnings, @errors) = ();
	push(
		# Valid feature, but check for required params
		@errors, "Feature 'override-subdomain' requires params.subdomain_prefix to be defined"
	) if $self->want_feature('override-subdomain') && !$self->env->lookup('params.subdomain_prefix');

	$self->validate_features(
		valid_features      => [
			'external-db', 'mysql', 'postgres',
			'deployment-name-in-domains',
			'override-subdomain'
		],
		deprecated_features => {
			'cf-v1-support' => undef
		},
		warnings            => \@warnings,
		errors              => \@errors
	);
}

# }}}
# validate_ocfp_features - Validate features for OCFP deployments {{{
sub validate_ocfp_features {
	my ($self) = @_;

	$self->validate_features(
		valid_features              => ['ocfp', 'internal-db'],
		mutually_exclusive_features => {database => [qw(postgres mysql)]},
	);
}

# }}}

### Feature processing methods

# process_classic_features - Process features for classic (non-OCFP) deployments {{{
sub process_classic_features {
	my ($self) = @_;

	# Add base manifest files required by all deployments
	$self->add_base_manifest_files();

	# Process CF compatibility files
	$self->process_cf_compatibility_files();

	# Process database configuration
	$self->process_database_configuration(
		!$self->want_feature('external-db'),
		$self->want_feature('mysql') ? 'mysql' : 'postgres'
	);

	# Process features
	for my $feature ($self->features) {
		if ($feature eq 'deployment-name-in-domains') {
			$self->add_files("overlay/deployment-name-in-domains.yml");
		} elsif ($feature eq 'override-subdomain') {
			$self->add_files("overlay/change_subdomain.yml");
		} elsif ($feature =~ /operations\/(.*)/) {
			$self->add_files("upstream/operations/$1.yml");
		} elsif (-f $self->env->path("ops/$feature.yml")) {
			$self->add_files($self->env->path("ops/$feature.yml"));
		}
		# noop_feature and other features handled by categorization
	}
	return $self->done();
}

# }}}
# process_ocfp_features - Process features for OCFP deployments {{{
sub process_ocfp_features {
	my ($self) = @_;

	# Add base manifest files required by all deployments
	$self->add_base_manifest_files();

	# Process CF compatibility files
	$self->process_cf_compatibility_files();

	# Base OCFP configuration - these are automatically included
	$self->add_files(
		"ocfp/meta.yml",
		"ocfp/ocfp.yml",
		"ocfp/broker.yml"
	);

	# Process database configuration for OCFP
	$self->process_ocfp_database_configuration();

	# Process features
	for my $feature ($self->features) {
		if ($feature =~ /operations\/(.*)/) {
			$self->add_files("upstream/operations/$1.yml");
		} elsif (-f $self->env->path("ops/$feature.yml")) {
			$self->add_files($self->env->path("ops/$feature.yml"));
		}
		# Basic features are automatically included in OCFP - no need to process
		# noop_feature and ocfp_feature already handled
	}
	return $self->done();
}

# }}}

### Helper methods for perform, validate_* and process_* methods

# get_cf_integration_data - Validate CF integration and retrieve exodus data {{{
sub get_cf_integration_data {
	my ($self) = @_;

	# Get CF deployment exodus data
	my $cf_env  = $self->env->lookup(['params.cf_deployment_env', 'genesis.env']);
	my $cf_type = $self->env->lookup('params.cf_deployment_type', 'cf');
	my $cf_exodus = $self->env->exodus_lookup('.', undef, "$cf_env/$cf_type");
	bail(
		"Failed to retrieve exodus data for %s/%s.", $cf_env, $cf_type
	) unless $cf_exodus && ref($cf_exodus) eq 'HASH' && keys %$cf_exodus;

	return $cf_exodus;
}

# }}}
# check_version_compatibility - Validate overlay vs upstream version compatibility {{{
sub check_version_compatibility {
	my ($self) = @_;

	# Note: We replace the upstream template with a version that uses BOSH variables
	#       to better customize domain usage.  When upgrading to a new upstream version,
	#       you may need to update the overlay/app-autoscaler.yml file to match the
	#       new upstream template.
	my $overlay_version  = (
		load_yaml_file( $self->kit->path("overlay/app-autoscaler.yml")) || {}
	)->{meta}{overlay_version} // 'unknown';
	my $upstream_version = (
		load_yaml_file( $self->kit->path("overlay/upstream_version.yml")) || {}
	)->{exodus}{'app-autoscaler-release-version'} // 'unknown';

	# Only compare versions if both are known (not 'unknown')
	if ($overlay_version ne 'unknown' && $upstream_version ne 'unknown') {
		warning(
			"Version Mismatch - The overlay/app-autoscaler.yml file is based on ",
			"version %s, but the upstream version is %s.  This may cause issues.",
			$overlay_version, $upstream_version
		) unless by_semver($overlay_version,$upstream_version) == 0;
	} elsif ($overlay_version eq 'unknown') {
		warning(
			"Unable to determine overlay version from overlay/app-autoscaler.yml - ",
			"please ensure meta.overlay_version is set correctly"
		);
	} elsif ($upstream_version eq 'unknown') {
		warning(
			"Unable to determine upstream version from overlay/upstream_version.yml - ",
			"please ensure exodus.app-autoscaler-release-version is set correctly"
		);
	}
}

# }}}
# add_base_manifest_files - Add core manifest files required by all deployments {{{
sub add_base_manifest_files {
	my ($self) = @_;

	# Base manifest files
	$self->add_files(
		"overlay/app-autoscaler.yml",
		"upstream/operations/add-releases.yml",
		"overlay/base.yml",
		"overlay/update_domains.yml",
		"overlay/add-postgress-variables.yml",
		"overlay/ten-year-ca-expiry.yml",
		"overlay/db-persistent-disk.yml",
		"overlay/upstream_version.yml",
		"overlay/change_network_details.yml",
		"overlay/releases/app-autoscaler.yml"
	);
}

# }}}
# process_cf_compatibility_files - Add CF version-specific compatibility files {{{
sub process_cf_compatibility_files {
	my ($self) = @_;
	my $cf_kit_version = $self->{_cf_exodus}{kit_version} // '0.0.0';

	# Add compatibility files for newer CF kit versions
	$self->add_files(
		"overlay/enable-nats-tls.yml",
		"overlay/enable-log-cache.yml",
		"overlay/instance-identity-cert-from-cf.yml",
	) if (new_enough($cf_kit_version, "2.3.0"));

	# Add compatible releases from the CF deployment (if provided)
	if (exists($self->{_cf_exodus}{releases})) {
		my $releases = JSON::PP
			->new->utf8(1)->allow_nonref(1)->allow_bignum(1)->allow_singlequote(1)
			->decode($self->{_cf_exodus}{releases});
		save_to_yaml_file({releases => $releases}, $self->kit->path(
			"overlay/cf-releases.dynamic.yml"
		));
		$self->add_files("overlay/cf-releases.dynamic.yml");
	}
}

# }}}
# check_upgrade_compatibility - Check for upgrade compatibility issues {{{
sub check_upgrade_compatibility {
	my ($self) = @_;

	# Check previous kit version for upgrade compatibility
	my $prev_version = $self->env->exodus_lookup("kit_version", "");
	if ($prev_version ne "") {
		# Check if previous version is compatible
		bail(
			"Detected previous deployment of CF App Autoscaler kit v%s - please upgrade to at ".
			"least cf-app-autoscaler kit 3.0.0 before upgrading to current version",
			$prev_version
		) if (!new_enough($prev_version, "3.0.0-rc.0"));

		# Check for specific version compatibility issues
		warning(
			"Upgrading from CF App Autoscaler kit v%s - please review changelog for ".
			"potential breaking changes in feature configuration",
			$prev_version
		) if (new_enough($prev_version, "3.0.0") && !new_enough($prev_version, "3.1.0"));
	}
}

# }}}
# process_database_configuration - Process database configuration for classic mode {{{
sub process_database_configuration {
	my ($self, $local, $db) = @_;

	if ($local) {
		$self->add_files(
			"upstream/operations/cf-mysql-db.yml", # Pretty sure this is very broken
			"overlay/no-postgres.yml",
		) if $db eq 'mysql';
	} else {
		$self->add_files(
			"overlay/fix-upstream-db-opsfiles.yml",
			"upstream/operations/external-db.yml",
			"overlay/external_db/common.yml",
			"overlay/no-postgres.yml",
			"overlay/external_db/$db.yml"
		);
	}
}

# }}}
# process_ocfp_database_configuration - Process database configuration for OCFP mode {{{
sub process_ocfp_database_configuration {
	my ($self) = @_;

	if (! $self->want_feature('internal-db')) {
		$self->add_files(
			"overlay/fix-upstream-db-opsfiles.yml",
			"upstream/operations/external-db.yml",
			"overlay/external_db/common.yml",
			"overlay/no-postgres.yml",
			"ocfp/ocfp-external-db.yml"
		);
	}
}

# }}}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:

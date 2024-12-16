#!/usr/bin/env perl
package Genesis::Hook::Blueprint::Bosh v3.0.4;

use strict;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Blueprint);

use Genesis qw/bail info warning error in_array new_enough/;

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
	my $cf_env  = $blueprint->env->lookup(['params.cf_deployment_env', '.genesis.env']);
	my $cf_type = $blueprint->env->lookup('params.cf_deployment_type', 'cf');
	bail(
		"Could not determine CF deployment environment"
	) unless $cf_env && $cf_type;
	my $cf_exodus = $blueprint->env->exodus_lookup('.', "$cf_env/$cf_type");
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
		"overlay/app-autoscaler.yml", # Will be replaced with processed version of upstream.
		"overlay/base.yml",
		"overlay/update_domains.yml", # May no longer be needed
		"overlay/add-postgress-variables.yml", # Move to base.yml 
		"overlay/upstream_version.yml",
		"overlay/change_deployment_and_network.yml",
		"overlay/enable-nats-tls.yml", # This explicitly disables non-TLS nats
		"overlay/enable-log-cache.yml",
		"overlay/instance-identity-cert-from-cf.yml",
		"overlay/releases/app-autoscaler.yml"
	);

	if (exists($cf_exodus->{releases})) {
		save_to_yaml_file($cf_exodus->{releases}, "overlay/cf-releases.dynamic.yml");
		$blueprint->add_files(
			"overlay/cf-releases.dynamic.yml",
		);
	}

	if ($blueprint->want_feature('ocfp')) {
		# Validate OCFP-compatible features
		$blueprint->validate_features(qw(ocfp internal-db));
		$blueprint->add_files(
			"ocfp/ocfp.yml",
			"ocfp/broker.yml",
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
		$blueprint->validate_features(qw(
			postgres mysql deployment-name-in-domains external-db
			override-subdomain
		));
		bail(
			"Cannot specify both postgres and mysql features"
		) if $blueprint->want_feature('postgres') && $blueprint->want_feature('mysql');

		
		if ($blueprint->want_feature('deployment-name-in-domains')) {
			$blueprint->add_files("overlay/deployment-name-in-domains.yml");
		)
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
				"upstream/operations/cf-mysql-db.yml",
				"overlay/no-postgres.yml",
			);
		}
		external-db)
			manifests+=(
				"overlay/fix-upstream-db-opsfiles.yml"
				"upstream/operations/external-db.yml"
				"overlay/external_db/common.yml"
				"overlay/no-postgres.yml"
			)
			if want_feature mysql; then
				manifests+=(
					"overlay/external_db/mysql.yml"
				)
			else
				manifests+=("overlay/external_db/postgres.yml")
			fi
			;;
		postgres)
			: # Default
			;;
		mysql)
			if ! want_feature external-db; then
				manifests+=(
					"overlay/fix-upstream-db-opsfiles.yml"
					"upstream/operations/cf-mysql-db.yml"
					"overlay/no-postgres.yml"
				)
			fi
			;;
	}

=tbd
if (lookup --defined "params.subdomain_prefix" 2>/dev/null); then
  manifests+=("overlay/change_subdomain.yml") # FIXME: Totally at odds with upstream domains
fi
=cut


# Do features => opsfiles stuff here
for want in $GENESIS_REQUESTED_FEATURES; do
  case "$want" in
  ocfp)
    manifests+=(
      "ocfp/ocfp.yml"
      "ocfp/broker.yml"
    )

    # FIXME:  Need to support external_db unless 'internal-db' is specified
    # ( added ocfp/extrnal-db.yml to support external-db)
    #        "overlay/fix-upstream-db-opsfiles.yml"
    #        "upstream/operations/external-db.yml"
    #        "overlay/external_db/common.yml"
    #        "overlay/no-postgres.yml"
    ;;
  override-subdomain) # Remove as a feature
    : # Already handled above
    ;;
  deployment-name-in-domains) # FIXME: Implement this feature
    :
    ;;
  external-db)
    manifests+=(
      "overlay/fix-upstream-db-opsfiles.yml"
      "upstream/operations/external-db.yml"
      "overlay/external_db/common.yml"
      "overlay/no-postgres.yml"
    )
    if want_feature mysql; then
      manifests+=(
        "overlay/external_db/mysql.yml"
      )
    else
      manifests+=("overlay/external_db/postgres.yml")
    fi
    ;;
  postgres)
    : # Default
    ;;
  mysql)
    if ! want_feature external-db; then
      manifests+=(
        "overlay/fix-upstream-db-opsfiles.yml"
        "upstream/operations/cf-mysql-db.yml"
        "overlay/no-postgres.yml"
      )
    fi
    ;;
  cf-v1-support) # FIXME: Remove this feature
    if new_enough "$cf_kit_version" "2.3.0"; then
      bail "Feature #C{cf-v1-support} is no longer supported by cf kit v2.3.0 or later"
    fi
    manifests+=("overlay/cf-v1-support.yml")
    ;;
  *)
    if [[ $want =~ operations/.* ]]; then
      if [[ -f "upstream/$want.yml" ]]; then
        manifests+=("upstream/$want.yml")
      else
        __bail "$GENSIS_KIT_ID does not support the $want feature"
      fi
    elif [[ -f "${GENESIS_ROOT}/ops/$want.yml" ]]; then
      mkdir -p "$(dirname "local_ops/$want.yml")"
      cp "$GENESIS_ROOT/ops/$want.yml" "local_ops/$want.yml"
      manifests+=("local_ops/$want.yml")
    else
      __bail "$GENESIS_KIT_ID does not support the #c{$want} feature"
    fi
    ;;
  esac
done

echo "${manifests[@]}" >"/tmp/$GENESIS_ENVIRONMENT.yamls"
echo "${manifests[@]}"

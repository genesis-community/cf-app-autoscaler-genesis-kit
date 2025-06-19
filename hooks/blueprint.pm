package Genesis::Hook::Blueprint::AppAutoscaler;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Blueprint);

use Genesis qw/bail new_enough/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->{files} = [];
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;

  # Basic manifests for all deployments
  $self->add_files(
    "upstream/templates/app-autoscaler.yml",
    "upstream/operations/add-releases.yml",
    "overlay/base.yml",
    "overlay/update_domains.yml",
    "overlay/add-postgress-variables.yml",
    "overlay/ten-year-ca-expiry.yml",
    "overlay/db-persistent-disk.yml",
    "overlay/upstream_version.yml",
    "overlay/change_deployment_and_network.yml",
    "overlay/releases/app-autoscaler.yml"
  );

  # Handle subdomain_prefix param
  if ($self->env->defines('params.subdomain_prefix')) {
    $self->add_files("overlay/change_subdomain.yml");
  }

  # Get CF deployment exodus data
  my $cf_env = $self->env->lookup('params.cf_deployment_env', $self->env->name);
  my $cf_type = $self->env->lookup('params.cf_deployment_type', 'cf');
  my $cf_exodus = $self->env->exodus_lookup('.', {}, "$cf_env/$cf_type");

  # Get CF kit version
  my $cf_kit_version = $cf_exodus->{kit_version};
  bail("#R{[ERROR]} Could not determine kit version with associated CF deployment")
    unless $cf_kit_version;

  # Validate postgres and mysql features aren't both specified
  if ($self->want_feature('postgres') && $self->want_feature('mysql')) {
    bail("#R{[ERROR]} Cannot specify both postgres and mysql features");
  }

  # Add NATS TLS and other files if CF version is new enough
  if (new_enough($cf_kit_version, "2.3.0")) {
    $self->add_files(
      "overlay/enable-nats-tls.yml",
      "overlay/enable-log-cache.yml",
      "overlay/instance-identity-cert-from-cf.yml",
      "overlay/releases/cf-kit-2.3.0-compatibility.yml"
    );
  }

  # Handle features
  foreach my $feature ($self->features) {
    if ($feature eq 'ocfp') {
      $self->add_files(
        "overlay/fix-upstream-db-opsfiles.yml",
        "upstream/operations/external-db.yml",
        "overlay/external_db/common.yml",
        "overlay/no-postgres.yml",
        "ocfp/meta.yml",
        "ocfp/ocfp.yml",
        "ocfp/broker.yml"
      );
    }
    elsif ($feature eq 'override-subdomain') {
      # Already handled above
    }
    elsif ($feature eq 'external-db') {
      $self->add_files(
        "overlay/fix-upstream-db-opsfiles.yml",
        "upstream/operations/external-db.yml",
        "overlay/external_db/common.yml",
        "overlay/no-postgres.yml"
      );

      if ($self->want_feature('mysql')) {
        $self->add_files("overlay/external_db/mysql.yml");
      } else {
        $self->add_files("overlay/external_db/postgres.yml");
      }
    }
    elsif ($feature eq 'postgres') {
      # Default, nothing to do
    }
    elsif ($feature eq 'mysql') {
      if (!$self->want_feature('external-db')) {
        $self->add_files(
          "overlay/fix-upstream-db-opsfiles.yml",
          "upstream/operations/cf-mysql-db.yml",
          "overlay/no-postgres.yml"
        );
      }
    }
    elsif ($feature eq 'cf-v1-support') {
      if (new_enough($cf_kit_version, "2.3.0")) {
        bail("Feature #C{cf-v1-support} is no longer supported by cf kit v2.3.0 or later");
      }
      $self->add_files("overlay/cf-v1-support.yml");
    }
    elsif ($feature =~ /operations\/.*/) {
      if (-f "upstream/$feature.yml") {
        $self->add_files("upstream/$feature.yml");
      } else {
        bail("$self->kit->id does not support the $feature feature");
      }
    }
    elsif (-f $self->env->path("ops/$feature.yml")) {
      $self->add_files("local_ops/$feature.yml");
    }
    else {
      bail("$self->kit->id does not support the #c{$feature} feature");
    }
  }

  # Return the list of files
  return $self->done;

	return $self->done(1);

}

1;
# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:

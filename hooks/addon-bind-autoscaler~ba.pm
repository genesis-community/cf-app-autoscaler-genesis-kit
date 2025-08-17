package Genesis::Hook::Addon::CFAppAutoscaler::BindAutoscaler;

use v5.20;
use warnings;

# Only needed for development
BEGIN { push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME} . '/.genesis/lib' }

use parent qw(Genesis::Hook::Addon);
use Genesis qw/info run bail/;

# Include common methods from mixin
BEGIN {
	require File::Basename;
	my $mixin_file = File::Basename::dirname(__FILE__) . '/_lib_addon.pm';
	do $mixin_file or die "Failed to include addon mixin $mixin_file: $!";
}

sub cmd_details {
	return "Binds the Autoscaler service broker to your deployed CF.";
}

sub perform {
	my ($self) = @_;

	# Log in to CF and get service broker credentials
	$self->cf_login();

	my ($sb_username, $sb_password, $sb_url) = $self->get_service_broker_credentials();

	info("Creating and enabling service broker");
	info("\ncf create-service-broker autoscaler $sb_username $sb_password $sb_url");

	my ($out, $rc) = run(
		qw/cf create-service-broker autoscaler/, $sb_username, $sb_password, $sb_url
	);
	if ($rc) {
		# Check if it's just because it already exists
		if ($out && $out =~ /Name must be unique/) {
			info("\nService broker already exists, updating it...");
			info("\ncf update-service-broker autoscaler $sb_username $sb_password $sb_url");
			run(
				{onfailure => "Failed to update service broker", interactive => 1},
				qw/cf update-service-broker autoscaler/, $sb_username, $sb_password, $sb_url
			);
		} else {
			bail("Failed to create service broker: $out");
		}
	}

	my $env_name = $self->env->name;

	info("cf enable-service-access autoscaler -b autoscaler");
	run(
		{onfailure => "Failed to enable service access for autoscaler"},
		qw/cf enable-service-access /, "autoscaler", "-b", "autoscaler"
	);

	info("\n#G{[OK]} Successfully created the service broker.");
	return $self->done();
}

1;

# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:

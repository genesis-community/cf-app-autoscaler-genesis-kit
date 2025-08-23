package Genesis::Hook::Addon::CFAppAutoscaler::UpdateAutoscaler v5.0.0;

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
	return "Updates the Autoscaler service broker information to your deployed CF.";
}

sub perform {
	my ($self) = @_;

	# Log in to CF and get service broker credentials
	$self->cf_login();
	my ($sb_username, $sb_password, $sb_url) = $self->get_service_broker_credentials();

	# Update service broker
	run(
		{onfailure => "Failed to update service broker", interactive => 1},
		qw/cf update-service-broker autoscaler/, $sb_username, $sb_password, $sb_url
	);

	info("#G{[OK]} Successfully updated autoscaler service broker.");
	return $self->done();
}

1;

# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:

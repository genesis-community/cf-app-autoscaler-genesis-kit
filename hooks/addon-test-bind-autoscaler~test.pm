package Genesis::Hook::Addon::CFAppAutoscaler::TestBindAutoscaler;

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
	return "Tests binding the Autoscaler service broker to your deployed CF " .
	       "and then removes it.";
}

sub perform {
	my ($self) = @_;

	# Log in to CF and get service broker credentials
	$self->cf_login();
	my ($sb_username, $sb_password, $sb_url) = $self->get_service_broker_credentials();

	# Create test service broker
	my $create_success = run(
		{passfail => 1, interactive => 1},
		'cf', 'create-service-broker', 'test-bind-autoscaler', $sb_username, $sb_password, $sb_url
	);

	my $enable_success = 0;
	my $service_name = $self->exodus_data("service_name");
	if ($create_success) {
		info("\n#G{[OK]} Successfully created test-bind-autoscaler service broker.");

		# Enable service access
		$enable_success = run(
			{passfail => 1, interactive => 1},
			'cf', 'enable-service-access', $service_name, '-b', 'test-bind-autoscaler'
		);

		if ($enable_success) {
			info("#G{[OK]} Successfully enabled service access for test-bind-autoscaler.");
		} else {
			info("#R{[FAILED]} Could not enable service access for test-bind-autoscaler.");
		}
	} else {
		info("#R{[FAILED]} Could not create test-bind-autoscaler service broker.");
	}

	# Clean up - always attempt to delete the test service broker
	info("\nCleaning up test service broker...");
	run(
		{passfail => 1, interactive => 1},
		'cf', 'delete-service-broker', 'test-bind-autoscaler', '-f'
	);

	# Return appropriate status based on test results
	if ($create_success && $enable_success) {
		info("#G{[OK]} Test completed successfully - service broker creation and access enabling worked.");
		return $self->done();
	} else {
		info("#R{[FAILED]} Test failed - see output above for details.");
		return $self->done(1); # Return with error status
	}
}

1;

# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:

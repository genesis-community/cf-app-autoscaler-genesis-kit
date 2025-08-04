package Genesis::Hook::Addon::CFAppAutoscaler::SetupCFPlugin;

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
	return "Adds the 'autoscaler' plugin to the cf cli. Use #y{-f} option" .
	       "to bypass confirmation prompt.";
}

sub perform {
	my ($self) = @_;

	# Parse options
	my %options = $self->parse_options(['f']);

	# Log in to CF first
	$self->cf_login();

	info("\n#Wkiu{Attempting to install latest version of the CF-Community/app-autoscaler-plugin...}");

	# Get existing plugin version
	my ($existing) = run('cf plugins --checksum | grep AutoScaler | tr -s \' \' | cut -d \' \' -f 2');
	chomp($existing);

	# Install plugin with optional force flag
	my @install_args = ('cf', 'install-plugin', '-r', 'CF-Community', 'app-autoscaler-plugin');
	push @install_args, @{$self->{args}} if @{$self->{args}};
	run(@install_args);

	# Get updated plugin version
	my ($updated) = run('cf plugins --checksum | grep AutoScaler | tr -s \' \' | cut -d \' \' -f 2');
	chomp($updated);

	if (!$updated) {
		# FIXME: If this happens, we need to handle it because it's likely an error
		info("");
		return $self->done(0);
	}

	if ($existing eq $updated) {
		info("No update - existing app-autoscaler-plugin remains at version $existing");
		return $self->done();
	}

	my $action = $existing ? "updated" : "installed";
	my ($header) = run('cf plugins | head -n3 | tail -n1');
	chomp($header);

	print "\n";
	print "$header\n";
	my ($separator) = run('echo "$1" | sed -e \'s/[^ ] [^ ]/xxx/g\' | sed -e \'s/[^ ]/-/g\'', $header);
	chomp($separator);
	print "$separator\n";

	my ($plugin_line) = run('cf plugins | grep AutoScaler');
	chomp($plugin_line);
	print "$plugin_line\n";

	info("\n#G{[OK]} Successfully $action CF-Community app-autoscaler-plugin.  " .
	     "     You can run #c{cf uninstall-plugin AutoScaler} to remove it when no " .
	     "     longer desired.");

	return $self->done();
}

1;

# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:

package Genesis::Hook::Addon::CFAppAutoscaler::SetupCFPlugin v5.0.0;

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
	return "Adds the 'autoscaler' plugin to the cf cli. Use #y{-f} option " .
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
  my ($plugins_out, $rc) = run(qw/cf plugins --checksum/);
  bail("Failed to list cf plugins") if $rc;
  my $existing = _find_autoscaler_version($plugins_out);

	# Ensure CF-Community repo exists
	my ($repos_out, $rcrc) = run(qw/cf list-plugin-repos/);
	bail("Failed to list plugin repos") if $rcrc;
	if ($repos_out !~ /^CF-Community\b/m) {
		run(
			{ onfailure => "Failed to add CF-Community plugin repo" },
			'cf', 'add-plugin-repo', 'CF-Community', 'https://plugins.cloudfoundry.org/'
		);
	}

	# Install plugin with optional force flag
  my @install_args = ('cf', 'install-plugin', '-r', 'CF-Community', 'app-autoscaler-plugin');
  push @install_args, '-f' if $options{f};
  my (undef, $irc) = run(
    { interactive => !$options{f}, onfailure => "Failed to install app-autoscaler-plugin" },
    @install_args
  );
  bail("Failed to install app-autoscaler-plugin") if $irc;

	# Get updated plugin version
  my ($plugins_out2, $rc2) = run(qw/cf plugins --checksum/);
  bail("Failed to list cf plugins after install") if $rc2;
  my $updated = _find_autoscaler_version($plugins_out2);

	if (!$updated) {
		# FIXME: If this happens, we need to handle it because it's likely an error
		info("");
		return $self->done(0);
	}

  if (defined $existing && $existing eq $updated) {
    info("No update - existing app-autoscaler-plugin remains at version $existing");
    return $self->done();
  }

	my $action = $existing ? "updated" : "installed";
  my ($plugins_table, $tc) = run(qw/cf plugins/);
  print "\n$plugins_table\n" if $plugins_table;

	info("\n#G{[OK]} Successfully $action CF-Community app-autoscaler-plugin.\n" .
			"You can run #c{cf uninstall-plugin AutoScaler} to remove it when no longer desired.");

	return $self->done();
}

# Helper: extract the autoscaler plugin version from `cf plugins --checksum`
sub _find_autoscaler_version {
  my ($text) = @_;
  for my $line (split /\n/, $text // '') {
    # Handle both printed names some CLIs use
    if ($line =~ /^(?:AutoScaler|app-autoscaler-plugin)\s+([^\s]+)/i) {
      return $1;
    }
  }
  return "";
}

1;

# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:

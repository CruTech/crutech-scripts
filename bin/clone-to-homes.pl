#! /usr/bin/env perl
use strict;
use warnings;

use feature qw( say );

use Getopt::Long;
use Pod::Usage;

use Path::Tiny;

# Add our project lib directory to the module search path
use FindBin qw( $Bin );
use lib path($Bin)->parent->child('lib')->stringify;
use Crutech::Utils qw( ltsp_users run );


#
# Handle CLI arguments
#

my $help;
my $man;
GetOptions(
    "help|?"          => \$help,
    "man"             => \$man,
) or pod2usage(2);

#helps
pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;

#
# Collect environement and configuration info
#

# Collect users grab their uid and gid numbers. template is added in for development and testing.
my @target_users = map {
	my $stat = $_->stat;
	{home => $_, uid => $stat->uid, gid => $stat->gid}
} map {
	path("/home/$_/") 
} (ltsp_users(), 'template');

say "Updating homes for: \n" . join("\t\n", map { join ', ', @{$_}{qw(home uid gid)} } @target_users);

my $project = path($Bin)->parent;
my $config_path = $project->child('config')->child('update-homes');

my $home = path('~/');
say "Defaulting to $home";

my $chroot_prefix = path('/opt/ltsp/amd64');
my $chroot_cache = path('/crutech/cache');
my $cache = $chroot_prefix->child($chroot_cache);
say "Cache set to $cache";
$cache->mkpath;
die "Unable to set ownership of $cache" 
	unless run(qw(ltsp-chroot -m chown root), "$chroot_cache")
		and run(qw(ltsp-chroot -m chgrp root), "$chroot_cache");



my $cache_linker = $home->child('.cache-linker');
say "Cache linker set to $home";
$cache_linker->spew("#! /bin/bash\n# Cache linker file generated: " . localtime());
chmod 550, $cache_linker->stringify;

# Set the minimum and maximum binary sizes to be considered for caching
my ($cache_min, $cache_max) = map { $_ * 1024 * 1024 } (10, 500);

#
# Read config files
#

# Ignore list
my $ignore_file = $config_path->child('ignore-list');
say "Loading file ignore patterns from file $ignore_file";
my @ignore_patterns = load_pattern_file($ignore_file);
push @ignore_patterns, "^$home\$";
say "Ignore patterns:\n" . join("\n", @ignore_patterns) if @ignore_patterns;

# Template list
my $template_file = $config_path->child('template-list');
say "Loading file template patterns from file $template_file";
my @template_patterns = load_pattern_file($template_file);
say "Template patterns:\n" . join("\n", @template_patterns) if @template_patterns;

# no cache list
my $no_cache_file = $config_path->child('no-cache-list');
say "Loading no cache patterns from file $no_cache_file";
my @no_cache_patterns = load_pattern_file($no_cache_file);
say "Template patterns:\n" . join("\n", @no_cache_patterns) if @no_cache_patterns;

#
# Travese home directory
#

my $file_iterator = $home->iterator( {
    recurse => 1,
} );

my $file_count = 0;
my $ignored_count = 0;
my $template_count = 0;
my $home_size = 0;
my $cache_size = 0;
while ( my $path = $file_iterator->() ) {

	if (my @ignore_matches = grep { $path =~ m/$_/ } @ignore_patterns) {
		++$ignored_count;
		say "Ignored file: $path due to ignore rules: '" . join("', '", @ignore_matches) . "'";
	}
	elsif (my @template_matches = grep { $path =~ m/$_/ } @template_patterns) {
		++$template_count;
		say "Template file: $path according rules: '" . join("', '", @template_matches) . "'";
		for my $user (@target_users) {
			my $content = replace_home_path($path->slurp, $user->{home}->stringify);
			say $content;
			write_template($path, $home, $user, $content);

		}
		$home_size += $path->stat->size;
	}
	else {
		# Make dir and move on
		if ($path->is_dir) {
			mkdir_for_user($home, $_, $path) for @target_users;
			next
		}
		#else

		# Cache or Copy file
		++$file_count;
		my $size = $path->stat->size;
		if ($size >= $cache_min and $size <= $cache_max) {
			if (my @matches = grep { $path =~ m/$_/ } @no_cache_patterns) {
				say "Rejected caching: $path according to no cache rules: '" . join("', '", @matches) . "'"
			}
			else {
				# Cache
				$cache_size += $size;
				say "Cacheable file: (" . bytes_to_mb($size) . "MB) $path";
				my $cached_file = add_to_cache($cache, $path);
				# Add softlink command to cache linker script
				$cache_linker->append("ln -s $cached_file $path\n");
				next
			}
		}

		# Copy
		$home_size += $size;
		add_to_home($home, $_, $path) for @target_users; 
    	# say $path;
	}
}

# Add completed linker script to user homes
for my $user (@target_users) {
	my $content = replace_home_path($cache_linker->slurp, $user->{home}->stringify);
	write_template($cache_linker, $home, $user, $content);
}
$home_size += $cache_linker->stat->size;

# Include cache linker in .bashrc
for my $user (@target_users) {
		my $bashrc = $home->child('.bashrc');
		my $linker_call = "# Add in symlinks to cahced files\nsources \$HOME/.cache-linker";
		if ($bashrc->slurp !~ m/quote_meta($linker_call)/) {
				$bashrc->append("\n$linker_call\n")
		}
}

#
# Report stats
#
say "Discovered $file_count files, templated $template_count files and ignored $ignored_count files";
say sprintf "Projected home size of %sMB and cache size of %sMB", bytes_to_mb($home_size), bytes_to_mb($cache_size);


#
# Routines
#

# Load regex config list
sub load_pattern_file {
	my $file = shift;
	# Read lines and filter empty and comment lines, then remove new lines
	map { chomp($_); $_ } grep { $_ !~ m/^\s*$/ and $_ !~ m/^\s*\#/ } $file->lines;
}

# Format byte count so it's easier to read
sub bytes_to_mb {
	sprintf '%.2f', shift(@_) / 1024 / 1024
}

# Replace one home path with another
sub replace_home_path {
	my $text = shift;
	my $new_home = shift;
	
	$text =~ s/ \/ home \/ \w+ \/ /$new_home\//grmx
}

# Add a file to a user home and give the user ownership
sub add_to_home {
	my $source_home = shift;
	my ($user_home, $uid, $gid) = @{shift(@_)}{qw(home uid gid)};
	my $path = shift;

	my $new_path = $path->copy( $user_home . substr("$path", length("$source_home")) );
	chown $uid, $gid, $new_path->stringify;

	$new_path;
}

# Add a directory to another user with matching permissions as a given directory
sub mkdir_for_user {
	my $source_home = shift;
	my ($user_home, $uid, $gid) = @{shift(@_)}{qw(home uid gid)};
	my $path = shift;

	my $new_path = path( $user_home . substr("$path", length("$source_home")) );
	$new_path->mkpath({
		mode => $path->stat->mode,
		owner => $uid,
		group => $gid,
	});

	$new_path
}

# Add a file to the image cache
sub add_to_cache {
	my $cache_dir = shift;
	my $path = shift;

	my $new_path = $path->copy( $cache_dir->child(substr($path =~ s/\//-/gr, 1)) );
	chmod 0665, $new_path->stringify;
	# Set ownership according to the images uid and gid
	# die "Unable to set ownership of cached file" 
	#	unless run(qw(ltsp-chroot -m chown), $new_path->stringify) and run(qw(ltsp-chroot -m chgrp root), $new_path->stringify);

	$new_path
}

# Create executable file
sub write_template {
	my $path = shift;
	my $source_home	= shift;
	my ($user_home, $uid, $gid) = @{shift(@_)}{qw(home uid gid)};
	my $content = shift;

	my $new_path = path( $user_home . substr("$path", length("$source_home")) );
	$new_path->spew($content);
	chown $uid, $gid, $new_path->stringify;
	chmod $path->stat->mode, $new_path->stringify;

	$new_path
}

__END__

=head1 NAME

clone-to-homes.pl - A script for cloneing one user's home to many users.

=head1 SYNOPSIS

clone-to-homes.pl [options]

Options:

 --help             brief help message

 --man              complete doc

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exit.

=item B<--man>

Print this man page and exit.


=back

=head1 DESCRIPTION

B<This program> Searches the current user's home directory and copies the content to camp user's home directories.

The concept is to try provide a system where a template user can be treated as a WYSIWYG editable version of new camp users.
To control this process there are a collection of filter defenitions in `config/update-homes` which allow for exclusion and special treatment of specified files.
For example if you are running minecraft, the template user can log in and perform the initial content downloads and then when the uesr is cloned, all the content will be copied into the target user's homes.
The filters are written as regular expressions applied to a file's path.
There are currently three filter defenitions.

The ignore-list defines the first set of filters applied to files found during the user cloneing process.
The patterns defined in this file will cause a file path which matches to be rejected, else the file will continue along the filter chain.

The template-list defines filters to catch files which may need their content rewritten to work in the context of a different user.
If a file matches this filter it will be copied in text mode and any verbatim use of the current user's home path will be replaced with the target user's home path.
If a file does not match this filtered it will be binary copied into the target user's directory structure.

The no-cache-list is currently set to disable for all files as this feature is not yet out of the experimental stage.
This feature is considering the posability of collecting large read-only files into a commonley accesable shared structure and dynamically symlinked into a user's directory tree on login.

Caveats
* Be careful not to copy any sensitive data into user directories!
* The size of the template home is effectivly multiplied by every user you clone to, be sure not to run out of disk space!
* This script will overwrite existing files, Be careful not to overwrite someone else's data!
* This script does not clean up a targeted user's home before copying to the user, for consistent results, only copy to a clean targets.
=cut
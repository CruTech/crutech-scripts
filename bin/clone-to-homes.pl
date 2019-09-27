#! /usr/bin/env perl
use strict;
use warnings;

use feature qw( say );

use Path::Tiny;

# Add our project lib directory to the module search path
use FindBin qw( $Bin );
use lib path($Bin)->parent->child('lib')->stringify;
use Crutech::Utils qw( ltsp_users run );

# Collect users grab their uid and gid numbers. template is added in for dev
my @target_users = map { my $stat = $_->stat; {home => $_, uid => $stat->uid, gid => $stat->gid} } map { path("/home/$_/") } (ltsp_users(), 'template');

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

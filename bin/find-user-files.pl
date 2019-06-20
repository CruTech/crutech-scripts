#! /usr/bin/env perl
use strict;
use warnings;
use feature qw( say );
use Getopt::Long;
use Pod::Usage;
use Digest::SHA qw( sha256 );
use IO::Compress::Zip qw(zip $ZipError);
use File::Spec;

use FindBin qw( $Bin );
chdir $Bin;
chdir '..';

use lib 'lib';
use Crutech::Utils;

my $template_dir;

my $ignore_list_file_name;
my $archive_dir;
my $help;
my $man;
GetOptions(
  "template=s"      => \$template_dir,
  "ignore-list=s"   => \$ignore_list_file_name,
  "archive-dir=s"   => \$archive_dir,
  "help|?"          => \$help,
  "man"             => \$man,
) or pod2usage(2);

#helps
pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;

# defaults
$ignore_list_file_name = 'config/ignore-file-list.txt' unless Crutech::Utils::has_content($ignore_list_file_name);
$template_dir = 'templates/user-home-template' unless Crutech::Utils::has_content($template_dir);

# help for required args error:
pod2usage(1) unless Crutech::Utils::has_content($archive_dir);


# Further process and report args
$archive_dir = File::Spec->rel2abs( $archive_dir ) or die "Unable to resolve arch-dir '$archive_dir': $!";
say '=' x 78;
say "| Archive output dir: '$archive_dir'";

my @ignore_file = Crutech::Utils::has_content($ignore_list_file_name) ? split( "\n", Crutech::Utils::slurp($ignore_list_file_name) ) : ();
say '=' x 78;
say "| Ignored files:";
say '-' x 78;
say join "\n", @ignore_file;

#report user list
say '=' x 78;
say "| User list:";
say '-' x 78;
say join "\n", Crutech::Utils::ltsp_users;

say '=' x 78;

my %template;
foreach my $file ( list_contents_recursive($template_dir) ) {
  $template{normalise_path($file, $template_dir)} = sha256(Crutech::Utils::slurp($file)) unless scalar grep { $_ eq normalise_path($file, $template_dir) } @ignore_file;
}

foreach my $user ( Crutech::Utils::ltsp_users ) {
  my @user_files;
  my $path = "/home/$user";
  foreach my $file ( list_contents_recursive($path) ) {
    if (exists $template{normalise_path($file, $path)}) {
      # say "$file exists in template";
      if (sha256(Crutech::Utils::slurp($file)) ne $template{normalise_path($file, $path)}) {
        # say "$file content does not match template";
        push @user_files, $file;
      }
    }
    else {
      # say "$file does not exist in template as: " . normalise_path($file, $path);
      push @user_files, $file unless scalar grep { $_ eq normalise_path($file, $path) } @ignore_file;
    }
  }
  say '-' x 78;
  say $user;
  say '-' x 78;
  say join "\n", @user_files;

  if (@user_files) {
    zip \@user_files => "$archive_dir/$user.zip" or die "zip failed: $ZipError\n";
  }
}

sub list_contents_recursive {
  my $path = @_ ? shift(@_) : die "list_contents_recursive expected one argument \$path!";
  my @files;

  opendir(my $dir_handle, $path) or die "Unable to open dir '$path': $!";
  while (my $node = readdir $dir_handle) {
    if ( -d "$path/$node" and $node !~ m/^\./ ) {
      push @files, list_contents_recursive("$path/$node");
    }
    else {
      push @files, "$path/$node" if $node !~ m/^\./;
    }
  }
  closedir $dir_handle;

  @files
}

sub normalise_path {
  my ($path, $prefix) = (shift(@_), shift(@_));
  substr $path, length($prefix), length($path);
}

__END__

=head1 NAME

find-user-files.pl - a script for retirving user files after camp.

=head1 SYNOPSIS

find-user-files.pl [options]

Options:

 --help             brief help message

 --man              complete doc

 --template         The path to the template directory (default: 'templates/user-home-template')

 --ignore-list      The path to our ignored files list (default: 'config/ignore-file-list.txt')

 --archive-dir      The path to save zip archives to. (required)

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exit.

=item B<--man>

Print this man page and exit.

=item B<--template>

A path to a directory to which user homes will be diffed against.
The results of this difference calculation determine which files have been changed or added by a user.

=item B<--ignore-list>

A path to a text file containing files to be ignored when comparing user home directories.
The format is for one file path per line.
File paths are relative to a user's home directory.
There are currently no wild-card features so all names are literal.

=item B<--archive-dir>

A path to save zip archives to.

=back

=head1 DESCRIPTION

B<This program> compares user directories against an example template.
Files are collected if they are new or changed.
Collected files are placed in a zip archive named after the user in the arch-dir.

=cut

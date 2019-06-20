#! /usr/bin/env perl
use strict;
use warnings;
use feature qw( say );
use Getopt::Long;
use Pod::Usage;
use FindBin qw( $Bin );
chdir $Bin;
chdir '..';

use lib 'lib';
use Crutech::Utils;

my $template_file;
my $out;
my $help;
my $man;
GetOptions(
  "out=s"           => \$out,
  "template=s"      => \$template_file,
  "help|?"          => \$help,
  "man"             => \$man,
) or pod2usage(2);

#helps
pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;

# help for required args error:
pod2usage(1) unless Crutech::Utils::has_content($template_file) and Crutech::Utils::has_content($out);

open(my $template_fh, "<", $template_file) or die "Unable to open '$template_file': $!";
my $template = do {
  local $/;
  <$template_fh>;
};
close $template_fh;

foreach my $user (Crutech::Utils::ltsp_users) {
  say "adding to $user...";
  my $out_content = $template;
  $out_content =~ s/<<user>>/$user/g;
  open(my $out_fh, ">", "/home/$user/$out") or die "Unable to open '/home/$user/$out': $!";
  print $out_fh $out_content;
  close $out_fh;
  die "Unable to chown '/home/$user/$out'!" if system "chown $user /home/$user/$out";
}

__END__

=head1 NAME

add-template-to-homes.pl - A script for adding a templated file to user homes for a camp.

=head1 SYNOPSIS

add-template-to-homes.pl [options]

Options:

 --template         The path to the template to process (Required!)

 --out              The path, relative to user's home, to output to (Required!)

 --help             brief help message

 --man              complete doc

=head1 OPTIONS

=over 8

=item B<--template>

The path to a template file to process.
Currently the only implemented token is <<user>> for a user's username.

=item B<--out>

The file name to output processed templates to.
The output path is relative to the subject user's home directory.

=item B<--help>

Print a brief help message and exit.

=item B<--man>

Print this man page and exit.


=back

=head1 DESCRIPTION

B<This program> Adds a processed template file to user home directories.

=cut

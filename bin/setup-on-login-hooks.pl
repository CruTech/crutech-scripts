#! /usr/bin/env perl
use strict;
use warnings;
use feature qw( say );
use Getopt::Long;
use Pod::Usage;
use FindBin qw( $Bin );
chdir $Bin;
chdir '..';

use feature qw( say );

use lib 'lib';
use Crutech::Utils;

my $out;
my $help;
my $man;
GetOptions(
  "out=s"           => \$out,
  "help|?"          => \$help,
  "man"             => \$man,
) or pod2usage(2);

#helps
pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;

# Commands to append to ~/.profile
my $build_actions = sub {
    my $user = shift;

    join "\n", (
        "mkdir -p /home/$user/Documents/Replays/Starcraft",
        "ln -s /home/$user/Documents/Replays/Starcraft /crutech/starcraft/Maps/replays/my-replays",
    );
};

foreach my $user (Crutech::Utils::ltsp_users) {
  say "adding to $user...";
  my $out_content = $build_actions->($user);
  open(my $out_fh, ">>", "/home/$user/.profile") or die "Unable to open '/home/$user/.profile': $!";
  print $out_fh "\n" . $out_content;
  close $out_fh;
}

__END__

=head1 NAME
setup-on-login-hooks.pl - A script for adding action to user's .profile scripts.

=head1 SYNOPSIS

setup-on-login-hooks.pl [options]

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

B<This program> Appends actions to user's .profile which will be executed when the user logs into their profile.

=cut

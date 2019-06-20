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

my $help;
my $man;
GetOptions(
    "help|?"          => \$help,
    "man"             => \$man,
) or pod2usage(2);

#helps
pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;

#report user list
say '=' x 78;
say "| User list:";
say '-' x 78;
say join "\n", Crutech::Utils::ltsp_users;

say '=' x 78;

foreach my $user (Crutech::Utils::ltsp_users) {
    say "Updating $user...";
    die "Unable to copy home template!" if system "cp -R ./templates/user-home-template/* /home/$user/";
    die "Unable to chown new home!" if system "chown -R $user /home/$user/*";
    die "Unable to add user to starcraft group!" if system "usermod -a -G starcraft $user";
}

# Example template call:
# die "Unable to install gish icon template!" if system "bin/add-template-to-homes.pl templates/gish.desktop.template Desktop/gish.desktop";

die "Unable to install gish icon template!" if system "bin/setup-on-login-hooks.pl";

__END__

=head1 NAME

setup-users.pl - A script for setting up user homes for a camp.

=head1 SYNOPSIS

setup-users.pl [options]

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

B<This program> Sets up user home directories for new users.
The template directory is found in projects templates/user-home-template directory.
Templates can be added via calling the add-template-to-homes script.

Currently this scipt adds items from the template and sets up groups for starcraft.
Following this the template for gish is added to all user's desktops.

=cut

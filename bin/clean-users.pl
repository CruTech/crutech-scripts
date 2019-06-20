#! /usr/bin/env perl
use strict;
use warnings;
use feature qw( say );
use Getopt::Long;
use Pod::Usage;
use Cwd;
my $calling_cwd = getcwd;
use FindBin qw( $Bin );
my $cwd = cwd;
chdir $Bin;
chdir '..';

use lib 'lib';
use Crutech::Utils qw(
    ltsp_users
    run
);

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
say '| User list:';
say '-' x 78;
say join "\n", ltsp_users;

say '=' x 78;

chdir $calling_cwd;
foreach my $user (ltsp_users) {
    say $user;
    run('deluser', '--remove-home', $user) or die "Failed removing user '$user'!\n";
}
say '-=complete=-';

__END__

=head1 NAME

clean-users.pl - A script for cleaning up user homes after a camp.

=head1 SYNOPSIS

clean-users.pl [options]

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

B<This program> removes users and saves their files to an archive in your current working directory.

=cut

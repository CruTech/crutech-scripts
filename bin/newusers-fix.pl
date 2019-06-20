#! /usr/bin/env perl
use strict;
use warnings;
use File::Temp qw/ tempfile tempdir /;
use Getopt::Long;
use Pod::Usage;
use FindBin qw( $Bin );
chdir $Bin;
chdir '..';

use lib 'lib';
use Crutech::Utils qw(
    has_content
    run
);

my $user_file;
my $out;
my $help;
my $man;
GetOptions(
    "user-file=s"     => \$user_file,
    "help|?"          => \$help,
    "man"             => \$man,
) or pod2usage(2);

#helps
pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;

# help for required args error:
pod2usage(1) unless has_content($user_file);

open(my $users, '<', $user_file) or die "Unable to open '$user_file' for read: $!";
while (my $user = <$users>) {
    my ($fh, $filename) = tempfile();
    print $fh $user;
    close $fh;

    run('newusers', $filename) or warn "Unable to add $user via newusers";
}
close $users;

__END__

=head1 NAME

newusers-fix.pl - A script for fixing the newusers bulk add issue.

=head1 SYNOPSIS

newusers-fix.pl [options]

Options:

 --user-file        A newusers compatible file (Required!)

 --help             brief help message

 --man              complete doc

=head1 OPTIONS

=over 8

=item B<--user-file>

A newusers compatible file.

=item B<--help>

Print a brief help message and exit.

=item B<--man>

Print this man page and exit.


=back

=head1 DESCRIPTION

B<This program> takes a newusers compatable file.

=cut

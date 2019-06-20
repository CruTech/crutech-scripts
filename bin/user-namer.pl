#! /usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use FindBin qw( $Bin );
chdir $Bin;
chdir '..';

use lib 'lib';
use Crutech::Utils qw(
    has_content
    slurp
);

my $user_list;
my $password_wordslist;
my $out;
my $help;
my $man;
GetOptions(
    "user-list=s"     => \$user_list,
    "word-list=s"     => \$password_wordslist,
    "out=s"           => \$out,
    "help|?"          => \$help,
    "man"             => \$man,
) or pod2usage(2);

#helps
pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;

# help for required args error:
pod2usage(1) unless has_content($user_list) and has_content($out);

$password_wordslist = 'config/password-wordlist.txt' unless has_content($password_wordslist);

my $numbers = [(2..5), (7..9)]; #no 0, 1 or 6
my $user_sequence = 19; #start somehwere in the double digits

#gather user names, seperating by line, and split multi-part names by spaces.
my @names = map {
                [
                    grep { has_content($_) }
                    split /\s+/, $_
                ]
            }
            grep { has_content($_) }
            split "\n",
            slurp($user_list);

# gather passwords words seperating on new lines
my $passwords = [
    grep { has_content($_) }
    split "\n",
    slurp($password_wordslist)
];

# prepare our file to output to
open(my $out_fh, '>', $out) or die "Unable to open out: '$out': $!";

foreach my $user (@names) {
    my $user_name = lc($user->[0]) . ($user_sequence++) . (scalar(@$user) > 1 ? lc($user->[1]) : '');
    my $user_pass = pick($passwords) . pick($numbers) . pick($passwords);
    print $out_fh "$user_name:$user_pass\:::"
        . (join ' ', @$user)
        . ":/home/$user_name:/bin/bash"
        . "\n";
}

close $out_fh;

print "-=Complete=-\n";

# Pick a random value from an array.
# Uses inbuilt rand function so this is not the best random sequence around
sub pick {
    my $array_ref = shift;
    die "pick(\@) : expected an array ref but recieved: '" . ref($array_ref) . "'\n" unless ref($array_ref) eq 'ARRAY';
    $array_ref->[int( rand(scalar(@$array_ref) - 1) )]
}

__END__

=head1 NAME

user-namer.pl - A script for generating adduser compatable user def files.

=head1 SYNOPSIS

user-namer.pl [options]

Options:

 --user-list        A file listing the name's of the users to generate (Required!)

 --word-list        A file listing words to use when generating passwords (Default: 'config/password-wordlist.txt')

 --out              The file to output the generated user list to (Required!)

 --help             brief help message

 --man              complete doc

=head1 OPTIONS

=over 8

=item B<--user-list>

A file with the name of a user on each line.
The input will be transformed to lowercase.
only a single name is nescisary however it is recommended to provide atleast a last initial in the case of duplicates.
see t/res/test-names.txt for an example.

=item B<--word-list>

A file containing words to be used when gernating passwords for users.
Each word must be on a seperate line.
These words will be combind by randomly picking one as a prefix and another as a suffix.
The two words are then joined with a number inbetween.

=item B<--out>

The file to write the generated user table to.
This file is compatable as input for the adduser command.

=item B<--help>

Print a brief help message and exit.

=item B<--man>

Print this man page and exit.


=back

=head1 DESCRIPTION

B<This program> creates an adduser compatable file.
Given a user list like
  Nigel
  Peter P
  Peter M
as the user-list argument.
A user name and password, generated from the word list, will be created and formatted for each name.
All user names will be lower case and the last initial is optional.
User names must be unique although currently no checks are caried out by this generator.

=cut

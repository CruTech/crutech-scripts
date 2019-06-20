#! /usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 7;


use lib 'lib';
use Crutech::Utils qw(
    has_content
    slurp
    run
    ltsp_users
);

is has_content(''), 0, 'has_content returns 0 on empty string';
is has_content(undef), 0, 'has_content returns 0 on undef';
is has_content('foo'), 1, 'has_content returns 1 on stringy content';
is has_content(0), 1, 'has_content returns 1 on numeric';

is has_content( slurp('t/res/test-names.txt') ), 1, 'slurp returns content';

ok run(qw(perl -e "exit 0")), 'Return true for command returning exitcode 0';
ok !run(qw(perl -e 'exit 1')), 'Return false for command returing non-zero exitcode';

# TODO
# ltsp_users tests

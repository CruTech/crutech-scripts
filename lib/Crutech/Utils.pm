package Crutech::Utils;
use strict;
use warnings;

use Exporter 'import';

our @EXPORT_OK = qw(ltsp_users slurp has_content run);

sub ltsp_users {
    # This should be updated to rely on an LTSP users group in the future
    grep { $_ =~ m/\d+\w*$/ } split "\n", `ls /home`;
}

sub slurp {
    my $file = shift(@_);
    local $/;
    open(my $fh, "<", $file) or die "Unable to open '$file': $!";
    return <$fh>;
}

sub has_content {
    my $string = shift;
    return 0 unless defined $string;
    return 0 unless length $string > 0;
    1
}

# A wrapper routine to map the exit code returned from system into a truethy value
# The returned value reflects the success of the call
sub run {
    if (system(@_) == 0) {
        return 1
    }
    else {
        return 0
    }
}

1;

#!/usr/bin/env perl

# This is a very simplistic version of 'cut'. It was written for performance comparisons,
# it is not intended for real work.

use 5.012;
use feature 'unicode_strings';
use open IO => ':encoding(utf8)';
use open ':std';

use Getopt::Long;
use strict;

&main();

sub help {
    my ($ostream) = @_;
    if (!defined($ostream)) { $ostream = *STDOUT; }
    print $ostream <<EOF;
Synopis: $0 [options] -- [file ...]

Options:
   --h|help                Print this help.
   --f|fields N [N ...]    Fields to cut. Specified as 1-upped indices.

EOF
}

sub main {
    my $b_help = 0;
    my @field_indices = ();

    my $r = GetOptions
      (
       'h|help!'     => \$b_help,
       'f|fields=i{,}'  => \@field_indices,
      );

    if (!$r) {
        &help(*STDERR);
        exit(1);
    } elsif ($b_help) {
        &help();
        return;
    }

    @field_indices = map { $_ - 1 } @field_indices;

    while (<>) {
        chomp();
        say join("\t", (split("\t", $_))[@field_indices]);
    }
}

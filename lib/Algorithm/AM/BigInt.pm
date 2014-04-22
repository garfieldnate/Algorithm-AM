package Algorithm::AM::BigInt;
use strict;
use warnings;
use Exporter::Easy (
    OK => ['bigcmp']
);
# ABSTRACT: Helper functions for AM big integers
# VERSION;

=head1 SYNOPSIS

 #todo

=head1 DESCRIPTION

AM uses custom big integers in its XS code, and they are sometimes
operated on in Perl code, as well. This package provides some helper
functions for working with them.

=head2 C<bigcmp>

Compares two big integers, returning 1, 0, or -1 depending on whether
the first argument is greater than, equal to, or less than the second
argument.

=cut
sub bigcmp {
    my($a,$b) = @_;
    return (length($a) <=> length($b)) || ($a cmp $b);
}

1;



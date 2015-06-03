package Algorithm::AM::BigInt;
use strict;
use warnings;
our $VERSION = '3.08';
# ABSTRACT: Helper functions for AM big integers
use Exporter::Easy (
    OK => ['bigcmp']
);

=head1 SYNOPSIS

 use Algorithm::AM::BigInt 'bigcmp';
 # get some big integers from Algorithm::AM::Result
 my ($a, $b);
 bigcmp($a, $b);

=head1 DESCRIPTION

AM uses custom 128-bit unsigned integers in its XS code, and these
numbers cannot be treated normally in Perl code. This package provides
some helper functions for working with these numbers.

=head2 DETAILS

Under the hood, the big integers used by AM are scalars with the
following fields:

=over

=item NV

This is an inexact double representation of the integer value.

=item PV

This is an exact string representation of the integer value.

=back

Operations on the floating-point representation will necessarily have a
small amount of error, so exact calculation or comparison requires
referencing the string field. The number field is still useful in
printing reports; for example, using C<printf>, where precision can
be specified.

Currently, the only provided helper function is for comparison of
two big integers.

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



# test that the Algorithm::AM is loaded properly
# Algorithm::AM uses Import::Into to also import
# Result, Project, and BigInt, so these must be
# checked as well.

use strict;
use warnings;
use Test::More tests => 6;
BEGIN {
    use_ok('Algorithm::AM')
        or BAIL_OUT(q{Couldn't load Algorithm::AM});
}
ok(scalar keys %Algorithm::AM::Result::,
    'Algorithm::AM::Result also imported');
ok(scalar keys %Algorithm::AM::BigInt::,
    'Algorithm::AM::BigInt also imported');
ok(exists $::{bigcmp}, 'bigcmp imported from BigInt');
ok(scalar keys %Algorithm::AM::DataSet::,
    'Algorithm::AM::DataSet also imported');
ok(exists $::{dataset_from_file},
    'dataset_from_file imported from DataSet');

__END__
# test the functionality of the Algorithm::AM::DataSet
use strict;
use warnings;
use Test::More 0.88;
plan tests => 10;
use Test::NoWarnings;
use Test::Exception;
use Algorithm::AM::DataSet::Item;

test_constructor();
test_accessors();

# test that the constructor lives/dies when given valid/invalid parameters
sub test_constructor {
    # The error should be thrown from Tiny.pm, the caller of DataSet,
    # not from DataSet (tests that @CARP_NOT is working properly).
    throws_ok {
        Algorithm::AM::DataSet::Item->new();
    } qr/Must provide 'features' parameter of type array ref.*Tiny.pm/,
    'constructor dies with missing features parameter';

    throws_ok {
        Algorithm::AM::DataSet::Item->new(features => 'hello');
    } qr/Must provide 'features' parameter of type array ref.*Tiny.pm/,
    'constructor dies with incorrect features parameter';

    lives_ok {
        Algorithm::AM::DataSet::Item->new(features => ['a','b']);
    } q[constructor doesn't die with good input];
    return;
}

# test that accessors work and have correct defaults
sub test_accessors {
    my $item = Algorithm::AM::DataSet::Item->new(
        features => ['a', 'b'], class => 'zed', comment => 'xyz');
    is_deeply($item->features, ['a', 'b'], 'features value');
    is($item->class, 'zed', 'class value');
    is($item->comment, 'xyz', 'comment value');
    is($item->cardinality, 2, 'cardinality');

    $item = Algorithm::AM::DataSet::Item->new(
        features => ['a', 'b', undef]);
    is($item->class, undef, 'class default value');
    is($item->comment, 'a,b,', 'comment default value');
}

# test the functionality of the Algorithm::AM::DataSet
use strict;
use warnings;
use Test::More 0.88;
plan tests => 16;
use Test::NoWarnings;
use Test::Exception;
use Algorithm::AM::DataSet;
use t::TestAM 'chapter_3_data';

test_constructor();
test_data();
test_private_data();

# test that the constructor lives/dies when given valid/invalid
# parameters, and that state is set correctly
sub test_constructor {
    throws_ok {
        Algorithm::AM::DataSet->new();
    } qr/Failed to provide 'vector_length' parameter/,
    q<dies without 'vector_length' parameter>;

    throws_ok {
        Algorithm::AM::DataSet->new(
            vector_length => 3,
            foo => 'bar',
            baz => 'buff'
        );
    } qr/Unknown parameters in Project constructor: baz, foo/,
    'dies with unknown parameters';

    lives_ok {
        Algorithm::AM::DataSet->new(
            vector_length => 3,
        );
    } 'constructor lives with normal input';
    my $dataset = Algorithm::AM::DataSet->new(vector_length => 3);
    is($dataset->vector_length, 3, 'vector_length set by constructor');
    return;
}

# test that add_data correctly adds data to the set and validates input
sub test_data {
    # first check empty project
    my $dataset = Algorithm::AM::DataSet->new(vector_length => 3);
    is($dataset->size, 0, 'new data set has 0 exemplars');
    is($dataset->num_classes, 0, 'new data set has 0 outcomes');

    $dataset->add_data(
        features => ['a','b','c'],
        class => 'b',
        comment => 'stuff'
    );
    is($dataset->size, 1,
        'add_data adds 1 exemplar to project');
    is($dataset->num_classes, 1, 'data set has 1 outcome');

    $dataset->add_data(
        features => ['a','b','d'],
        class => 'c',
        comment => 'stuff'
    );
    is($dataset->num_classes, 2, 'data set has 2 outcomes');

    is_deeply($dataset->get_features(1),[qw(a b d)],
        'data variables correctly set');
    is($dataset->get_comment(1),'stuff',
        'data spec correctly set');
    is($dataset->get_class(1), 'c',
        'data outcome correctly set');

    throws_ok {
        $dataset->add_data(
            features => ['3','1'],
            class => 'c',
            comment => 'comment'
        );
    } qr/Expected 3 variables, but found 2 in 3 1 \(comment\)/,
    'add_data fails with wrong number of variables';
    return;
}

# test all data for use by AM.pm (and the hooks) only
# hopefully this can be eliminated in the future, as private
# data should not have to be exposed
sub test_private_data {
    my $dataset = Algorithm::AM::DataSet->new(vector_length => 3);
    is_deeply($dataset->_exemplar_outcomes, [],
        "empty data set has empty outcomes");

    my @data = chapter_3_data();
    # get rid of one of the specs to test that it is filled in
    $data[1][2] = '';
    for my $datum(@data){
        $dataset->add_data(
            features =>$datum->[0],
            class => $datum->[1],
            comment => $datum->[2]);
    }

    is_deeply($dataset->_exemplar_outcomes, [qw(1 2 2 2 2)],
        "correct data set outcomes");
    return;
}

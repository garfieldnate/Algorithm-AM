# Check AM constructor and acessors (which are related)
use strict;
use warnings;
use Algorithm::AM;
use Test::More 0.88;
use Test::Exception;
use Test::NoWarnings;
plan tests => 8;
use FindBin qw($Bin);
use Path::Tiny;

my $corpus_path = path($Bin, 'data');
my $normal_path = path($corpus_path, 'chapter3');

test_input_checking();
test_project();

sub test_input_checking {
    throws_ok {
        Algorithm::AM->new();
    } qr/Missing required parameter 'train'/,
    'dies when no training set provided';

    throws_ok {
        Algorithm::AM->new(
            train => Algorithm::AM::DataSet->new(vector_length => 3)
        );
    } qr/Missing required parameter 'test'/,
    'dies when no test set provided';

    throws_ok {
        Algorithm::AM->new(
            train => 'stuff',
            test => Algorithm::AM::DataSet->new(vector_length => 3),
        );
    } qr/Parameter train should be an Algorithm::AM::DataSet/,
    'dies with bad training set';

    throws_ok {
        Algorithm::AM->new(
            train => Algorithm::AM::DataSet->new(vector_length => 3),
            test => 'stuff',
        );
    } qr/Parameter test should be an Algorithm::AM::DataSet/,
    'dies with bad test set';

    throws_ok {
        Algorithm::AM->new(
            train => Algorithm::AM::DataSet->new(vector_length => 3),
            test => Algorithm::AM::DataSet->new(vector_length => 3),
            foo => 'bar'
        );
    } qr/Unknown option foo/,
    'dies with bad argument';

    throws_ok {
        Algorithm::AM->new(
            train => Algorithm::AM::DataSet->new(vector_length => 3),
            test => Algorithm::AM::DataSet->new(vector_length => 4),
        );
    } qr/Training and test sets do not have the same cardinality \(3 and 4\)/,
    'dies with mismatched dataset cardinalities';
    return;
}

# test that constructor sets project properly
sub test_project {
    subtest 'AM constructor saves data sets' => sub {
        plan tests => 4;
        my $project_path = path($Bin, '..', 'data', 'chapter3');
        my $am = Algorithm::AM->new(
            train => Algorithm::AM::DataSet->new(vector_length => 3),
            test => Algorithm::AM::DataSet->new(vector_length => 3),
        );
        isa_ok($am->training_set, 'Algorithm::AM::DataSet',
            'training_set returns correct object type');
        isa_ok($am->test_set, 'Algorithm::AM::DataSet',
            'test_set returns correct object type');

        is($am->training_set->vector_length, 3,
            'training set saved');
        is($am->test_set->vector_length, 3,
            'test set saved');
    };
}

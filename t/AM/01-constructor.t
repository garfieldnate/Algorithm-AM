# Check AM constructor and acessors (which are related)
use strict;
use warnings;
use Algorithm::AM;
use Test::More 0.88;
use Test::Exception;
use Test::NoWarnings;
plan tests => 4;
use FindBin qw($Bin);
use Path::Tiny;

my $corpus_path = path($Bin, 'data');
my $normal_path = path($corpus_path, 'chapter3');

test_input_checking();
test_project();

sub test_input_checking {
    throws_ok {
        Algorithm::AM->new();
    } qr/Missing required input Algorithm::AM::Project object\./,
    'dies when no project provided';

    throws_ok {
        Algorithm::AM->new(
            Algorithm::AM::Project->new(variables => 3),
            foo => 'bar'
        );
    } qr/Unknown option foo/,
    'dies with bad argument';
    return;
}

# test that constructor sets project properly
sub test_project {
    subtest 'AM constructor is given Project object' => sub {
        plan tests => 2;
        my $project_path = path($Bin, '..', 'data', 'chapter3');
        my $am = Algorithm::AM->new(
            Algorithm::AM::Project->new(
                path => $project_path,
                variables => 3,
                commas => 0
            )
        );
        isa_ok($am->get_project, 'Algorithm::AM::Project',
            'get_project returns correct object type');
        is($am->get_project->base_path, $project_path,
            'correct project base path (project dir)');
    };
}

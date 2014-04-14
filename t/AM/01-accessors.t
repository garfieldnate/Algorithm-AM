# Check that AM object can be created and accessors return correct data
use strict;
use warnings;
use Algorithm::AM;
use Test::More 0.88;
plan tests => 5;
use Test::NoWarnings;
use FindBin qw($Bin);
use Path::Tiny;

test_get_project();

sub test_get_project {
    my $project_path = path($Bin, '..', 'data', 'chapter3');
    my $am = Algorithm::AM->new(
        $project_path,
        commas => 'no',
    );
    isa_ok($am->get_project, 'Algorithm::AM::Project',
        'get_project returns correct object type');
    is($am->get_project->base_path, $project_path,
        'correct project base path (project dir)');

    my $project = Algorithm::AM::Project->new();
    $am = Algorithm::AM->new($project);
    isa_ok($am->get_project, 'Algorithm::AM::Project',
        'get_project returns correct object type');
    is($am->get_project->base_path, $project->base_path,
        'correct project base path (current directory)');
    return;
}

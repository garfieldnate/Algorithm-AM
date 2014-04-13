# test the functionality of the Algorithm::AM::Project
# API; create projects programmatically instead of reading
# from the file system
use strict;
use warnings;
use Test::More;
plan tests => 27;
use Test::Exception;
use Test::NoWarnings;
use Algorithm::AM::Project;
use FindBin '$Bin';
use Path::Tiny;

my $data_dir = path($Bin, '..', 'data');

test_add_data();

test_paths();
test_format_vars();
test_data();
test_test_items();
test_private_data();

# test that add_data correctly adds data to the set and
# validates input
sub test_add_data {
    my $project = Algorithm::AM::Project->new();
    $project->add_data(['a','b','c'],'stuff','b', 'beta');
    is($project->num_exemplars, 1,
        'add_data adds 1 exemplar to project');

    throws_ok {
        $project->add_data(['3','1'],'comment','c', 'chi');
    } qr/Expected 3 variables, but found 2 in 3 1 \(comment\)/,
    'add_data fails with wrong number of variables';
    return;
}

sub test_paths {
    my $project = Algorithm::AM::Project->new();
    is($project->base_path, Path::Tiny->cwd,
        'correct base_path');
    return;
}

sub test_format_vars {
    # format variables don't make sense without data, so errors
    # are thrown here
    my $project = Algorithm::AM::Project->new();
    throws_ok {
        $project->var_format;
    } qr/must add data before calling var_format/,
        'error getting var_format before adding data';
    throws_ok {
        $project->spec_format;
    } qr/must add data before calling spec_format/,
        'error getting spec_format before adding data';
    throws_ok {
        $project->outcome_format;
    } qr/must add data before calling outcome_format/,
        'error getting outcome_format before adding data';
    throws_ok {
        $project->data_format;
    } qr/must add data before calling data_format/,
        'error getting data_format before adding data';
    return;
}

sub test_data {
    # first check empty project
    my $project = Algorithm::AM::Project->new();
    is($project->num_exemplars, 0, 'new project has 0 exemplars');
    is($project->num_variables, 0, 'new project has 0 variables');
    is($project->num_outcomes, 0, 'new project has 0 outcomes');
    is($project->num_variables, 0, 'new project has 0 variables');
    return;
}

# test the project test data
sub test_test_items {
    my $project = Algorithm::AM::Project->new();
    is($project->num_test_items, 0, 'no test items in empty project');

    $project->add_test([qw(a b c)], 'abc', 'foo', 'foo bar');
    is($project->num_test_items, 1, 'test item added');
    is($project->num_outcomes, 1, '1 outcome added via test item');
    is($project->get_outcome(1), 'foo bar',
        'correct outcome from test item');
    is($project->num_variables, 3, 'data size set via test item');
    is($project->short_outcome_index('foo'), 1,
        q<correct index of 'foo' outcome>);
    return;
}

# test all data for use by AM.pm (and the hooks) only
sub test_private_data {
    my $project = Algorithm::AM::Project->new();
    is_deeply($project->_outcome_list, [''],
        "empty project has empty outcome list");
    is_deeply($project->_outcomes, [],
        "empty project has empty outcomes");
    is_deeply($project->_data, [],
        "empty project has empty data");
    is_deeply($project->_specs, [],
        "empty project has empty specs");

    $project->add_data([qw(3 1 0)], 'myFirstCommentHere', 'e');
    $project->add_data([qw(2 1 0)], '', 'r');
    $project->add_data([qw(0 3 2)], 'myThirdCommentHere', 'r');
    $project->add_data([qw(2 1 2)], 'myFourthCommentHere', 'r');
    $project->add_data([qw(3 1 1)], 'myFifthCommentHere', 'r');

    is_deeply($project->_outcomes, [qw(1 2 2 2 2)],
        "correct project outcomes");
    is_deeply($project->_data, [
        [qw(3 1 0)],
        [qw(2 1 0)],
        [qw(0 3 2)],
        [qw(2 1 2)],
        [qw(3 1 1)]],
        "correct project data");
    is_deeply($project->_outcome_list, ['', 'e', 'r'],
        "correct project outcome list");

    #specs are slightly different because when one is missing the
    #data string is used instead
    my $specs = [
        'myFirstCommentHere',
        '2 1 0',
        qw(myThirdCommentHere
        myFourthCommentHere
        myFifthCommentHere)];

    is_deeply($project->_specs, $specs,
        'correct project specs (commas)');

    #also test with project containing outcomes file
    my $outcome_project = Algorithm::AM::Project->new(
        path($data_dir, 'chapter3_outcomes'), commas => 'no');
    is_deeply($outcome_project->_outcome_list, ['', 'ee', 'are' ],
        "correct project outcome list (with outcome file)");
    return;
}

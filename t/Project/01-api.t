# test the functionality of the Algorithm::AM::Project
# API; only create projects via methods for adding data (instead of
# reading project directories)
use strict;
use warnings;
use Test::More;
plan tests => 37;
use Test::Exception;
use Test::NoWarnings;
use Algorithm::AM::Project;
use t::TestAM 'chapter_3_data';
use FindBin '$Bin';
use Path::Tiny;

my $data_dir = path($Bin, '..', 'data');

test_data();
test_paths();
test_test_items();
test_private_data();
test_format_vars();

# test that add_data correctly adds data to the set, sets num_variables,
# and validates input
sub test_data {
    # first check empty project
    my $project = Algorithm::AM::Project->new();
    is($project->num_exemplars, 0, 'new project has 0 exemplars');
    is($project->num_variables, 0, 'new project has 0 variables');
    is($project->num_outcomes, 0, 'new project has 0 outcomes');

    $project->add_data(['a','b','c'],'b','stuff');
    is($project->num_exemplars, 1,
        'add_data adds 1 exemplar to project');
    is($project->num_variables, 3, 'project data set to three variables');
    is($project->num_outcomes, 1, 'project has 1 outcome');

    $project->add_data(['a','b','d'],'c','stuff');
    is($project->num_outcomes, 2, 'project has 2 outcomes');

    is_deeply($project->get_exemplar_data(1),[qw(a b d)],
        'data variables correctly set');
    is($project->get_exemplar_spec(1),'stuff',
        'data spec correctly set');
    is($project->get_exemplar_outcome(1), 2,
        'data outcome correctly set');

    throws_ok {
        $project->add_data(['3','1'], 'c', 'comment');
    } qr/Expected 3 variables, but found 2 in 3 1 \(comment\)/,
    'add_data fails with wrong number of variables';

    $project = Algorithm::AM::Project->new();
    throws_ok {
        $project->add_data([], 'c', 'comment');
    } qr/Found 0 data variables in input \(comment\)/,
    'add_data fails with 0 variables';
    return;
}

# test correct value for base_path
sub test_paths {
    my $project = Algorithm::AM::Project->new();
    is($project->base_path, undef,
        'base_path is undef when no directory is provided');
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

    # test with data made specially for testing format variables
    $project->add_data([qw(aaaaa bbb bbb)],
        'exception', 'myCommentHere');
    $project->add_data([qw(dd bbb bbb)],
        'regular',
        'myCommentHere blah blah blah blah');
    $project->add_data([qw(aaaaa cccc dd)], 'regular',
        'myCommentHere');
    $project->add_data([qw(dd bbb dd)], 'regular',
        'myCommentHere');
    $project->add_data([qw(aaaaa bbb bbb)], 'regular',
        'myCommentHere');
    $project->add_data([qw(aaaaa bbb dd)], 'exception',
        'myCommentHere');
    $project->add_data([qw(dd bbb bbb)],'regular',
        'myCommentHere blah blah blah blah longest!');

    is($project->var_format, '%-5.5s %-4.4s %-3.3s',
        'correct var_format');
    is($project->spec_format, '%-42.42s',
        'correct spec_format');
    is($project->outcome_format, '%-9.9s',
        'correct outcome_format');
    is($project->data_format, '%7.0u',
        'correct data_format');
    return;
}

# test the project test data
sub test_test_items {
    my $project = Algorithm::AM::Project->new();
    is($project->num_test_items, 0, 'no test items in empty project');

    $project->add_test([qw(a b c)], 'foo', 'abc');
    is($project->num_test_items, 1, 'test item added');
    is($project->num_outcomes, 1, '1 outcome added via test item');
    is($project->get_outcome(1), 'foo',
        'correct outcome from test item');
    is($project->num_variables, 3, 'data size set via test item');
    is($project->outcome_index('foo'), 1,
        q<correct index of 'foo' outcome>);

    # empty spec should be set to data string
    $project->add_test([qw(a b c)], 'foo');
    is_deeply($project->get_test_item(1),
        [1, [qw(a b c)], 'a b c',],
        'get_test_item returns correct test data');

    return;
}

# test all data for use by AM.pm (and the hooks) only
# hopefully this can be eliminated in the future, as private
# data should not have to be exposed
sub test_private_data {
    my $project = Algorithm::AM::Project->new();
    is_deeply($project->_outcome_list, [''],
        "empty project has empty outcome list");
    is_deeply($project->_exemplar_outcomes, [],
        "empty project has empty outcomes");
    is_deeply($project->_exemplar_vars, [],
        "empty project has empty data");
    is_deeply($project->_exemplar_specs, [],
        "empty project has empty specs");

    my @data = chapter_3_data();
    # get rid of one of the specs to test that it is filled in
    $data[1][2] = '';
    for my $datum(@data){
        $project->add_data(@$datum);
    }

    is_deeply($project->_exemplar_outcomes, [qw(1 2 2 2 2)],
        "correct project outcomes");
    # index 0 of each data entry contains the variables
    is_deeply($project->_exemplar_vars, [map {$_->[0]} @data],
        "correct project data");
    is_deeply($project->_outcome_list, ['', 'e', 'r'],
        "correct project outcome list");

    # index 2 of each data entry contains the specs
    my $specs = [$data[0][2], '2 1 0', map {$_->[2]} @data[2..4]];

    is_deeply($project->_exemplar_specs, $specs,
        'correct project specs (commas)');
    return;
}

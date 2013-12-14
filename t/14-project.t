#test the functionality of Algorithm::AM::Project
use strict;
use warnings;
use Test::More;
plan tests => 50;
use Test::Exception;
use Test::NoWarnings;
use Algorithm::AM::Project;
use FindBin '$Bin';
use Path::Tiny;

my $data_dir = path($Bin, 'data');

test_param_checking();
test_paths();
test_format_vars();
test_data();
test_data_errors();
test_private_data();

sub test_param_checking {
    throws_ok {
        Algorithm::AM::Project->new();
    } qr/Must specify project/,
    'dies without project parameter';

    throws_ok {
        Algorithm::AM::Project->new(path($data_dir, 'nonexistent'));
    } qr/Could not find project/,
    'dies with non-existent project path';

    throws_ok {
        Algorithm::AM::Project->new(
            path($data_dir, 'chapter3'));
    } qr/Failed to provide 'commas' parameter/,
    q<dies without 'commas' parameter>;

    throws_ok {
        Algorithm::AM::Project->new(
            path($data_dir, 'chapter3'),
            commas => 'whatever',
        );
    } qr/Failed to specify comma formatting correctly/,
    q<dies with incorrect 'commas' parameter>;

    throws_ok {
        Algorithm::AM::Project->new(
            path($data_dir, 'chapter3_no_data'),
            commas => 'yes');
    } qr/Project has no data file/,
    'dies when no data file in project';

    throws_ok {
        Algorithm::AM::Project->new(
            path($data_dir, 'chapter3'),
            commas => 'no', foo => 'bar', baz => 'buff');
    } qr/Unknown parameters in Project constructor: baz, foo/,
    'dies with unknown parameters';

    return;
}

sub test_paths {
    my $project = Algorithm::AM::Project->new(
        path($data_dir, 'chapter3'), commas => 'no');
    is($project->base_path, path($data_dir, 'chapter3'),
        'correct base_path');
    is($project->results_path, path($data_dir, 'chapter3', 'amcpresults'),
        'correct results_path');
    return;
}

sub test_format_vars {
    # test all format variables with and without comma use;
    # someday we may have more input formats to test
    my %inputs = (
        'no commas' => Algorithm::AM::Project->new(
            path($data_dir, 'chapter3'), commas => 'no'),
        commas => Algorithm::AM::Project->new(
            path($data_dir, 'chapter3_commas'), commas => 'yes'),
    );
    # sort keys for consistent test output
    for my $name (sort keys %inputs){
        my $project = $inputs{$name};
        is($project->var_format, (join ' ', ('%-1.1s') x 3),
            "correct var_format ($name)");
        is($project->spec_format, '%-19.19s',
            "correct spec_format ($name)");
        is($project->outcome_format, '%-1.1s',
            "correct outcome_format ($name)");
        is($project->data_format, '%5.0u',
            "correct data_format ($name)");
    }

    # test again with this project made specially for testing format
    # variables
    my $project = Algorithm::AM::Project->new(
        path($data_dir, 'format_test'), commas => 'yes');
    is($project->var_format, '%-5.5s %-4.4s %-3.3s',
        'correct var_format (format_test)');
    is($project->spec_format, '%-42.42s',
        'correct spec_format (format_test)');
    is($project->outcome_format, '%-14.14s',
        'correct outcome_format (format_test)');
    is($project->data_format, '%7.0u',
        'correct data_format (format_test)');
    return;
}

# test all data with and without comma use;
# someday we may have more input formats to test
sub test_data {
    my %inputs = (
        'no commas' => Algorithm::AM::Project->new(
            path($data_dir, 'chapter3'), commas => 'no'),
        commas => Algorithm::AM::Project->new(
        path($data_dir, 'chapter3_commas'), commas => 'yes')
    );
    # sort keys for consistent test output
    for my $name (sort keys %inputs){
        my $project = $inputs{$name};
        is($project->num_variables, 3, "3 variables in chapter3 data ($name)");
        is($project->num_exemplars, 5, "3 exemplars in chapter3 data ($name)");
        is_deeply($project->get_exemplar_data(4), [qw(3 1 1)],
            "correct exmplar data returned ($name)");
        is($project->get_exemplar_spec(0), 'myFirstCommentHere',
            "correct exmplar spec returned ($name)");
        #1 means the first index in $project->get_outcome
        is($project->get_exemplar_outcome(0), 1,
            "correct exmplar outcome returned ($name)");
        is($project->num_outcomes, 2, "correct number of outcomes ($name)");
        is($project->get_outcome(1), 'e',
            "correct outcome returned from list ($name)");
        is($project->short_outcome_index('e'), 1,
            "correct index of 'e' outcome ($name)");
    }

    #also test with project containing outcomes file
    my $outcome_project = Algorithm::AM::Project->new(
        path($data_dir, 'chapter3_outcomes'), commas => 'no');
    is($outcome_project->num_outcomes, 2,
        'correct number of outcomes (with outcome file)');
    is($outcome_project->get_outcome(1), 'ee',
        'correct outcome returned from list (with outcome file)');

    return;
}

sub test_data_errors {
    throws_ok {
        Algorithm::AM::Project->new(
            path($data_dir, 'chapter3_bad_data'),
            commas => 'no');
    } qr/Expected 3 variables, but found 2 in 3 1 \(myCommentHere\)/,
    'dies with mismatched number of variables';

    throws_ok {
        Algorithm::AM::Project->new(
            path($data_dir, 'chapter3_bad_outcomes'),
            commas => 'no');
    } qr/Found more items in data file than in outcome file/,
    'dies with mismatched number of outcomes';
    # TODO: test opposite, with more items in outcome file than
    # in data file

    return;
}

# test all data for use by AM.pm (and the hooks) only, with and
# without comma use;
# someday we may have more input formats to test
sub test_private_data {
    my %inputs = (
        'no commas' => Algorithm::AM::Project->new(
            path($data_dir, 'chapter3'), commas => 'no'),
        commas => Algorithm::AM::Project->new(
        path($data_dir, 'chapter3_commas'), commas => 'yes')
    );
    # sort keys for consistent test output
    for my $name (sort keys %inputs){
        my $project = $inputs{$name};
        is_deeply($project->_outcomes, [qw(1 2 2 2 2)],
            "correct project outcomes ($name)");
        is_deeply($project->_data, [
            [qw(3 1 0)],
            [qw(2 1 0)],
            [qw(0 3 2)],
            [qw(2 1 2)],
            [qw(3 1 1)]],
            "correct project data ($name)");
        is_deeply($project->_outcome_list, ['', 'e', 'r'],
            "correct project outcome list ($name)");
    }

    #specs are slightly different because when one is missing the
    #data string is used instead
    my $no_comma_specs = [qw(
        myFirstCommentHere
        210
        myThirdCommentHere
        myFourthCommentHere
        myFifthCommentHere)];
    is_deeply($inputs{'no commas'}->_specs, $no_comma_specs,
        'correct project specs (no commas)');

    my $comma_specs = $no_comma_specs;
    $comma_specs->[1] = '2 1 0';
    is_deeply($inputs{'commas'}->_specs, $comma_specs,
        'correct project specs (commas)');

    #also test with project containing outcomes file
    my $outcome_project = Algorithm::AM::Project->new(
        path($data_dir, 'chapter3_outcomes'), commas => 'no');
    is_deeply($outcome_project->_outcome_list, ['', 'ee', 'are' ],
        "correct project outcome list (with outcome file)");
    return;
}

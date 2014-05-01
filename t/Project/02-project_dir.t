# test the functionality in Algorithm::AM::Project
# related to reading AM project directories
use strict;
use warnings;
use Test::More;
plan tests => 10;
use Test::Exception;
use Test::Warn;
use Test::NoWarnings;
use Algorithm::AM::Project;
use t::TestAM qw(
    chapter_3_data
    chapter_3_test
);
use FindBin '$Bin';
use Path::Tiny;

my $data_dir = path($Bin, '..', 'data');

test_file_validity_checking();
test_project_errors();
test_paths();
test_data();

sub test_file_validity_checking {
    throws_ok {
        Algorithm::AM::Project->new(
            variables => 3,
            commas => 0,
            path => path($data_dir, 'chapter3_bad_data_line'));
    } qr/Couldn't read data at line 2 in .*_bad_data_line/,
    q<dies bad line in data file>;

    return;
}

# test that problems are detected in project data files
sub test_project_errors {
    throws_ok {
        Algorithm::AM::Project->new(
            variables => 3,
            path => path($data_dir, 'nonexistent'),
            commas => 0);
    } qr/Could not find project/,
    'dies with non-existent project path';

    throws_ok {
        Algorithm::AM::Project->new(
            variables => 3,
            path => path($data_dir, 'chapter3_no_data'),
            commas => 1);
    } qr/Project has no data file/,
    'dies when no data file in project';

    warning_like {
        Algorithm::AM::Project->new(
            variables => 3,
            path => path($data_dir, 'chapter3_no_test'),
            commas => 0);
    } {carped => qr/Couldn't open .*test at .*/},
    'warns when no test file in project';
    return;
}

sub test_paths {
    my $project = Algorithm::AM::Project->new(
        variables => 3, path => path($data_dir, 'chapter3'),
        commas => 0
    );
    is($project->base_path, path($data_dir, 'chapter3'),
        'project path');
    return;
}

# test all data with and without comma use;
# someday we may have more input formats to test
sub test_data {
    my $project;
    # test project reading by intercepting calls to add_data and add_test
    # and checking for character parameters
    my @data;
    my @test;
    no warnings 'redefine';
    # shift is so we don't test calling object
    local *Algorithm::AM::Project::add_data = sub {
        shift;
        push @data, [@_];
    };
    local *Algorithm::AM::Project::add_test = sub {
        shift;
        push @test, [@_];
    };

    # test plain project
    my @data_expected = chapter_3_data();
    # slightly change data because we leave one spec blank to test
    # that it is filled in
    $data_expected[1][2] = '210';
    my @test_expected = chapter_3_test();
    $project = Algorithm::AM::Project->new(
        variables => 3, path => path($data_dir, 'chapter3'),
        commas => 0);
    is_deeply(\@data, \@data_expected, "correct exemplar data (plain project)")
        or note explain \@data;
    is_deeply(\@test, \@test_expected, "correct test data (plain project)")
        or note explain \@test;

    # test comma-formatted project
    @data = @test = ();
    # slightly change data because we leave one spec blank to test
    # that it is filled in
    $data_expected[1][2] = '2 1 0';
    $project = Algorithm::AM::Project->new(
        variables => 3, path => path($data_dir, 'chapter3_commas'),
        commas => 1);
    is_deeply(\@data, \@data_expected,
        "correct exemplar data (commas project)");
    is_deeply(\@test, \@test_expected,
        "correct test data (commas project)");
    return;
}

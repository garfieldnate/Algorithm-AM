# Test correct classification.
# Mostly uses the example from chapter 3 of the green book

use strict;
use warnings;
use Algorithm::AM;
use Test::More 0.88;
plan tests => 7;
use Test::NoWarnings;
use Test::LongString;

use FindBin qw($Bin);
use Path::Tiny;
use File::Slurp;

test_quadratic();
test_linear();
test_nulls();

sub test_quadratic {
    my @data = (
      [[qw(3 1 0)], 'myFirstCommentHere', 'e', undef],
      [[qw(2 1 0)], '210', 'r', undef],
      [[qw(0 3 2)], 'myThirdCommentHere', 'r', undef],
      [[qw(2 1 2)], 'myFourthCommentHere', 'r', undef],
      [[qw(3 1 1)], 'myFifthCommentHere', 'r', undef]
    );
    my $project = Algorithm::AM::Project->new();
    for my $datum(@data){
        $project->add_data(@$datum);
    }
    $project->add_test([qw(3 1 2)], 'myCommentHere', 'r');
    #clean up previous test runs
    unlink $project->results_path
        if -e $project->results_path;

    my $am = Algorithm::AM->new(
        $project,
        commas => 'no',
    );
    $am->classify();
    my $results = read_file($project->results_path);
    like_string($results,qr/e\s+4\s+30.769%\v+r\s+9\s+69.231%/, 'Chapter 3 data, counting pointers')
        or note $results;
    like_string($results,qr/Gang: squared/, 'Chapter 3 data, counting occurences')
        or note $results;

    #clean up the amcpresults file
    unlink $project->results_path
        if -e $project->results_path;
    return;
}

sub test_linear {
    my @data = (
      [[qw(3 1 0)], 'myFirstCommentHere', 'e', undef],
      [[qw(2 1 0)], '210', 'r', undef],
      [[qw(0 3 2)], 'myThirdCommentHere', 'r', undef],
      [[qw(2 1 2)], 'myFourthCommentHere', 'r', undef],
      [[qw(3 1 1)], 'myFifthCommentHere', 'r', undef]
    );
    my $project = Algorithm::AM::Project->new();
    for my $datum(@data){
        $project->add_data(@$datum);
    }
    $project->add_test([qw(3 1 2)], 'myCommentHere', 'r');
    #clean up previous test runs
    unlink $project->results_path
        if -e $project->results_path;

    my $am = Algorithm::AM->new(
        $project,
        commas => 'no',
    );
    $am->classify(linear => 1);
    my $results = read_file($project->results_path);
    like_string($results,qr/e\s+2\s+28.571%\v+r\s+5\s+71.429%/, 'Chapter 3 data, counting occurences')
        or note $results;
    like_string($results,qr/Gang: linear/, 'Chapter 3 data, counting occurences')
        or note $results;

    #clean up the amcpresults file
    unlink $project->results_path
        if -e $project->results_path;
    return;
}

# test with null variables, using both exclude_nulls
# and include_nulls
# TODO: can there be nulls in the data, too? I think so...
sub test_nulls {
    my @data = (
      [[qw(3 1 0)], 'myFirstCommentHere', 'e', undef],
      [[qw(2 1 0)], '210', 'r', undef],
      [[qw(0 3 2)], 'myThirdCommentHere', 'r', undef],
      [[qw(2 1 2)], 'myFourthCommentHere', 'r', undef],
      [[qw(3 1 1)], 'myFifthCommentHere', 'r', undef]
    );
    my $project = Algorithm::AM::Project->new();
    for my $datum(@data){
        $project->add_data(@$datum);
    }
    $project->add_test([qw(= 1 2)], '', 'r');
    my $am = Algorithm::AM->new(
        $project,
        commas => 'no',
    );

    #clean up previous test runs
    unlink $project->results_path
        if -e $project->results_path;
    subtest 'exclude nulls' => sub {
        $am->classify(exclude_nulls => 1);
        my $results = read_file($project->results_path);
        like_string($results,qr/e\s+3\s+30.000%\v+r\s+7\s+70.000%/,
            'Results with exclude nulls')
            or note $results;
        like_string($results, qr/Nulls: exclude/,
            'Printing with exclude nulls')
            or note $results;
    };
    #clean up the amcpresults file
    unlink $project->results_path
        if -e $project->results_path;

    subtest 'include nulls' => sub {
        $am->classify(exclude_nulls => 0);
        my $results = read_file($project->results_path);
        like_string($results,qr/r\s+5\s+100.000%/, 'Include nulls')
            or diag $results;
        like_string($results, qr/Nulls: include/,
            'Printing with exclude nulls')
            or diag $results;
    };
    #clean up the amcpresults file
    unlink $project->results_path
        if -e $project->results_path;

    return;
}
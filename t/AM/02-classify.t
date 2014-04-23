# Test correct classification.
# Mostly uses the example from chapter 3 of the green book

use strict;
use warnings;
use Algorithm::AM;
use Test::More 0.88;
plan tests => 10;
use Test::NoWarnings;
use Test::LongString;

use FindBin qw($Bin);
use Path::Tiny;
use File::Slurp;

test_quadratic();
test_linear();
test_nulls();
test_given();
test_finnverb();

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
# TODO: test for the correct number of active variables
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
            or note $results;
        like_string($results, qr/Nulls: include/,
            'Printing with exclude nulls')
            or note $results;
    };
    #clean up the amcpresults file
    unlink $project->results_path
        if -e $project->results_path;

    return;
}

# test case where test data is in given data
sub test_given {
    my @data = (
      [[qw(3 1 0)], 'myFirstCommentHere', 'e', undef],
      [[qw(2 1 0)], '210', 'r', undef],
      [[qw(0 3 2)], 'myThirdCommentHere', 'r', undef],
      [[qw(2 1 2)], 'myFourthCommentHere', 'r', undef],
      [[qw(3 1 1)], 'myFifthCommentHere', 'r', undef],
      [[qw(3 1 2)], 'same as the test exemplar', 'r', undef]
    );
    my $project = Algorithm::AM::Project->new();
    for my $datum(@data){
        $project->add_data(@$datum);
    }
    $project->add_test([qw(3 1 2)], 'myCommentHere', 'r');
    my $am = Algorithm::AM->new(
        $project,
        exclude_given => 1
    );

    #clean up previous test runs
    unlink $project->results_path
        if -e $project->results_path;
    subtest 'exclude given' => sub {
        plan tests => 3;
        $am->classify();
        my $results = read_file($project->results_path);

        like_string($results,qr/e   4   30.769%\v+r   9   69.231%/,
            'Results for exclude given'
        ) or note $results;

        like_string($results, qr/If context is in data file then exclude/,
            'Flag should indicate exclude given'
        ) or note $results;

        unlike_string($results,
            qr/Include context even if it is in the data file/,
            'Flag should not indicate include given'
        ) or note $results;

    };
    #clean up the amcpresults file
    unlink $project->results_path
        if -e $project->results_path;

    subtest 'include given' => sub {
        plan tests => 3;
        $am->classify(exclude_given => 0);
        my $results = read_file($project->results_path);

        like_string($results,qr/r\s+15\s+100.000%/, 'Include given')
            or note $results;

        like_string($results, qr/Include context even if it is in the data file/,
         'Flag should indicate include given')
            or note $results;

        unlike_string($results, qr/If context is in data file then exclude/,
         'Flag should not indicate exclude given')
            or note $results;
    };
    #clean up the amcpresults file
    unlink $project->results_path
        if -e $project->results_path;

    return;
}

# test the finnverb data set; just check how many exemplars
# were correctly classified
sub test_finnverb {
    my $p = Algorithm::AM->new(
        path($Bin, '..', 'data', 'finnverb'),
        commas => 'no',
        exclude_given => 1,
    );

    my $count = 0;
    $p->classify(
        endtesthook   => sub {
            my ($am, $data) = @_;
            my $sum = $am->{sum};
            my $pointermax = $data->{pointermax};
            my $curTestOutcome = ${$data->{curTestOutcome}};
            ++$count if $sum->[$curTestOutcome] eq $pointermax;
        }
    );

    is($count, 161, '161 items correctly predicted');
}

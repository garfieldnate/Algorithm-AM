# Test correct classification.
# Mostly uses the example from chapter 3 of the green book

use strict;
use warnings;
use Algorithm::AM;
use Test::More 0.88;
plan tests => 8;
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
    subtest 'quadratic calculation' => sub {
        plan tests => 3;
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
        my $am = Algorithm::AM->new(
            $project,
            commas => 'no',
        );
        my ($result) = $am->classify();
        is($result->total_pointers, 13, 'total pointers')
            or note $result->total_pointers;;
        is($result->count_method, 'squared',
            'counting configured to quadratic');
        is_deeply($result->scores, {'e' => 4, 'r' => 9},
            'outcome scores') or
            note explain $result->scores;

        #clean up the amcpresults file
        unlink $project->results_path
            if -e $project->results_path;
    };
    return;
}

sub test_linear {
    subtest 'linear calculation' => sub {
        plan tests => 3;
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

        my $am = Algorithm::AM->new(
            $project,
            commas => 'no',
        );
        my ($result) = $am->classify(linear => 1);
        is($result->total_pointers, 7, 'total pointers')
            or note $result->total_pointers;;
        is($result->count_method, 'linear',
            'counting configured to quadratic');
        is_deeply($result->scores, {'e' => 2, 'r' => 5}, 'outcome scores')
            or note explain $result->scores;

        #clean up the amcpresults file
        unlink $project->results_path
            if -e $project->results_path;
    };
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
        plan tests => 3;
        my ($result) = $am->classify(exclude_nulls => 1);
        is($result->total_pointers, 10, 'total pointers')
            or note $result->total_pointers;
        ok($result->exclude_nulls, 'exclude nulls is true');
        is_deeply($result->scores, {'e' => 3, 'r' => 7},
            'outcome scores')
            or note explain $result->scores;
    };

    subtest 'include nulls' => sub {
        plan tests => 3;
        my ($result) = $am->classify(exclude_nulls => 0);
        is($result->total_pointers, 5, 'total pointers')
            or note $result->total_pointers;
        ok(!$result->exclude_nulls, 'exclude nulls is false');
        is_deeply($result->scores, {'r' => 5}, 'outcome scores')
            or note explain $result->scores;
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

    subtest 'exclude given' => sub {
        plan tests => 3;
        my ($result) = $am->classify();
        is($result->total_pointers, 13, 'total pointers')
            or note $result->total_pointers;
        ok($result->exclude_given, 'exclude given is true');
        is_deeply($result->scores, {'e' => 4, 'r' => 9}, 'outcome scores')
            or note explain $result->scores;
    };

    subtest 'include given' => sub {
        plan tests => 3;
        my ($result) = $am->classify(exclude_given => 0);
        is($result->total_pointers, 15, 'total pointers')
            or note $result->total_pointers;
        ok(!$result->exclude_given, 'exclude given is false');
        is_deeply($result->scores, {'r' => 15}, 'outcome scores')
            or note explain $result->scores;
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

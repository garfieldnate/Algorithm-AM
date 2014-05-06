# Test correct classification.
# Mostly uses the example from chapter 3 of the green book

use strict;
use warnings;
use Algorithm::AM;
use Test::More 0.88;
plan tests => 10;
use Test::NoWarnings;
use Test::LongString;
use t::TestAM qw(chapter_3_project chapter_3_data);

use FindBin qw($Bin);
use Path::Tiny;
use File::Slurp;

my $project = chapter_3_project();
my $am = Algorithm::AM->new($project);
my ($result) = $am->classify();
test_quadratic_classification($result);
test_analogical_set($result);
test_gang_effects($result);
test_linear_classification();
test_nulls();
test_given();
test_finnverb();

# test classification results using quadratic counting
sub test_quadratic_classification {
    my ($result) = @_;
    subtest 'quadratic calculation' => sub {
        plan tests => 3;
        is($result->total_pointers, 13, 'total pointers')
            or note $result->total_pointers;;
        is($result->count_method, 'squared',
            'counting configured to quadratic');
        is_deeply($result->scores, {'e' => 4, 'r' => 9},
            'outcome scores') or
            note explain $result->scores;
    };
    return;
}

# test classification results using linear counting
sub test_linear_classification {
    subtest 'linear calculation' => sub {
        plan tests => 3;
        my $project = chapter_3_project();
        my $am = Algorithm::AM->new($project);
        my ($result) = $am->classify(linear => 1);
        is($result->total_pointers, 7, 'total pointers')
            or note $result->total_pointers;;
        is($result->count_method, 'linear',
            'counting configured to quadratic');
        is_deeply($result->scores, {'e' => 2, 'r' => 5}, 'outcome scores')
            or note explain $result->scores;
    };
    return;
}

# test with null variables, using both exclude_nulls
# and include_nulls
# TODO: test for the correct number of active variables
sub test_nulls {
    my $project = Algorithm::AM::Project->new(variables => 3);
    for my $datum( chapter_3_data() ){
        $project->add_data(@$datum);
    }
    $project->add_test([qw(= 1 2)], '', 'r');
    my $am = Algorithm::AM->new($project);

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

    return;
}

# test case where test data is in given data
sub test_given {
    my $project = chapter_3_project();
    $project->add_data(
      [qw(3 1 2)], 'r', 'same as the test exemplar');
    my $am = Algorithm::AM->new(
        $project,
        exclude_given => 1
    );

    subtest 'exclude given' => sub {
        plan tests => 3;
        my ($result) = $am->classify();
        is($result->total_pointers, 13, 'total pointers')
            or note $result->total_pointers;
        ok($result->given_excluded, 'given item was excluded');
        is_deeply($result->scores, {'e' => 4, 'r' => 9}, 'outcome scores')
            or note explain $result->scores;
    };

    subtest 'include given' => sub {
        plan tests => 3;
        my ($result) = $am->classify(exclude_given => 0);
        is($result->total_pointers, 15, 'total pointers')
            or note $result->total_pointers;
        ok(!$result->given_excluded, 'given was not excluded');
        is_deeply($result->scores, {'r' => 15}, 'outcome scores')
            or note explain $result->scores;
    };
    return;
}

sub test_analogical_set {
    my ($result) = @_;
    subtest 'analogical set' => sub {
        plan tests => 5;
        my $set = $result->analogical_set();

        is_deeply($set, {0 => 4, 2 => 2, 3 => 3, 4 => 4},
            'data indices and pointer values') or note explain $set;
        # now confirm that the referenced data really are what we think
        is($project->get_exemplar_spec(0), 'myFirstCommentHere',
            'confirm first item')
            or note $project->get_exemplar_spec(0);
        is($project->get_exemplar_spec(2), 'myThirdCommentHere',
            'confirm third item')
            or note $project->get_exemplar_spec(2);
        is($project->get_exemplar_spec(3), 'myFourthCommentHere',
            'confirm fourth item')
            or note $project->get_exemplar_spec(3);
        is($project->get_exemplar_spec(4), 'myFifthCommentHere',
            'confirm fifth item')
            or note $project->get_exemplar_spec(4);
    };
    return;
}

sub test_gang_effects {
    my ($result) = @_;
    my $expected_effects = {
      '- - 2' => {
        'data' => {'r' => [2]},
        'effect' => '0.153846153846154',
        'homogenous' => 'r',
        'outcome' => {
          'r' => {
            'effect' => '0.153846153846154',
            'score' => '2'
          }
        },
        'score' => 2,
        'size' => 1,
        'vars' => ['','','2']
      },
      '- 1 2' => {
        'data' => {'r' => [3]},
        'effect' => '0.230769230769231',
        'homogenous' => 'r',
        'outcome' => {
          'r' => {
            'effect' => '0.230769230769231',
            'score' => '3'
          }
        },
        'score' => 3,
        'size' => 1,
        'vars' => ['','1','2']
      },
      '3 1 -' => {
        'data' => {'e' => [0], 'r' => [4]},
        'effect' => '0.615384615384615',
        'homogenous' => 0,
        'outcome' => {
          'e' => {
            'effect' => '0.307692307692308',
            'score' => 4
          },
          'r' => {
            'effect' => '0.307692307692308',
            'score' => 4
          }
        },
        'score' => 8,
        'size' => 2,
        'vars' => ['3','1', '']
      }
    };
    is_deeply($result->gang_effects, $expected_effects,
        'correct reported gang effects') or
        note explain $result->gang_effects;

    return;
}

# test the finnverb data set; just check how many exemplars
# were correctly classified
sub test_finnverb {
    my $am = Algorithm::AM->new(
        Algorithm::AM::Project->new(
            path => path($Bin, '..', 'data', 'finnverb'),
            variables => 10,
            commas => 0
        ),
        exclude_given => 1,
    );

    my $count = 0;
    $am->classify(
        endtesthook   => sub {
            my ($am, $test, $data, $result) = @_;
            my ($outcome, $variables, $spec) = @$test;
            ++$count if grep {$_ eq $outcome} @{$result->winners()};
        }
    );

    is($count, 161, '161 items correctly predicted');
}

use strict;
use warnings;
use Test::More 0.88;
plan tests => 2;
use Test::LongString;
use Algorithm::AM;

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

test_config_info();
test_result_info();

# test that the configuration information is correctly printed by
# the config_info method after setting internal state through
# the constructor.
sub test_config_info {
    subtest 'configuration info string' => sub {
        plan tests => 2;
        my $result = Algorithm::AM::Result->new(
            excluded_data => [0,1,2],
            given_excluded => 1,
            num_variables => 3,
            test_item => [qw(a b c)],
            test_spec => 'comment',
            test_outcome => 2,
            exclude_given => 1,
            exclude_nulls => 1,
            probability => 1,
            count_method => 'linear',
            datacap => 50,
            test_in_data => 1,
        );
        my $info = ${$result->config_info};
        is_string_nows($info, <<'END_INFO') or note $info;
Given Context:  a b c, comment
If context is in data file then exclude
Number of data items: 50
Probability of including any one data item: 1
Total Excluded: 3  + test item
Nulls: exclude
Gang: linear
Number of active variables: 3
Test item is in the data.
END_INFO
        $result = Algorithm::AM::Result->new(
            excluded_data => [],
            given_excluded => 0,
            num_variables => 3,
            test_item => [qw(a b c)],
            test_spec => 'comment',
            test_outcome => 2,
            exclude_given => 0,
            exclude_nulls => 0,
            probability => .5,
            count_method => 'squared',
            datacap => 40,
            test_in_data => 0,
        );

        $info = ${$result->config_info};
        is_string_nows($info, <<'END_INFO') or note $info;
Given Context:  a b c, comment
Include context even if it is in the data file
Number of data items: 40
Probability of including any one data item: 0.5
Total Excluded: 0
Nulls: include
Gang: squared
Number of active variables: 3
END_INFO
    };
    return;
}

# This tests all of the untestable AM-guts logic by running a single
# classification and checking the printed results.
# TODO: refactor so we can test individual aspects of a result, e.g.
# items in the analogical set, individual gang effects, etc.
sub test_result_info {
    subtest 'classification info printing' => sub {
        plan tests => 4;
        my $am = Algorithm::AM->new(
            $project,
            commas => 'no',
        );
        my ($result) = $am->classify();
        my $stats = ${$result->statistical_summary};
        is_string_nows($stats, <<'END_STATS') or note $stats;
Statistical Summary
e   4   30.769%
r   9   69.231%
   --
   13
Expected outcome: r
Correct outcome predicted.
END_STATS
        my $set = ${$result->analogical_set_summary};
        is_string_nows($set, <<'END_SET') or note $set;
Analogical Set
Total Frequency = 13
e  myFirstCommentHere    4   30.769%
r  myThirdCommentHere    2   15.385%
r  myFourthCommentHere   3   23.077%
r  myFifthCommentHere    4   30.769%
END_SET
        my $gang = ${$result->gang_summary(0)};
        is_string_nows($gang, <<'END_GANG') or note $gang;
Gang effects             3 1 2
 61.538%   8             3 1
------------
 30.769%   4 x     1  e
 30.769%   4 x     1  r
 23.077%   3               1 2
------------
 23.077%   3 x     1  r
 15.385%   2                 2
------------
 15.385%   2 x     1  r
END_GANG
        $gang = ${$result->gang_summary(1)};
        is_string_nows($gang, <<'END_GANG') or note $gang;
Gang effects             3 1 2
 61.538%   8             3 1
------------
 30.769%   4 x     1  e
                         3 1 0  myFirstCommentHere
 30.769%   4 x     1  r
                         3 1 1  myFifthCommentHere
 23.077%   3               1 2
------------
 23.077%   3 x     1  r
                         2 1 2  myFourthCommentHere
 15.385%   2                 2
------------
 15.385%   2 x     1  r
                         0 3 2  myThirdCommentHere
END_GANG

        #clean up the test run
        unlink $project->results_path
            if -e $project->results_path;
    };
    return;
}

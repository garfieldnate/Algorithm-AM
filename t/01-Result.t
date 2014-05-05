use strict;
use warnings;
use Test::More 0.88;
plan tests => 2;
use Test::LongString;
use Algorithm::AM;
use t::TestAM 'chapter_3_project';

my $project = chapter_3_project();
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
            exclude_nulls => 1,
            count_method => 'linear',
            datacap => 50,
            test_in_data => 1,
        );
        my $info = ${$result->config_info};
        my $expected = <<'END_INFO';
+----------------------------+----------------+
| Option                     | Setting        |
+----------------------------+----------------+
| Given Context              | a b c, comment |
| Number of data items       | 50             |
| Test Item Excluded         | yes            |
| Total Excluded             |  4             |
| Nulls                      | exclude        |
| Gang                       | linear         |
| Number of active variables |  3             |
| Test item in data          | yes            |
+----------------------------+----------------+
END_INFO
        is_string_nows($info, $expected,
            'given/nulls excluded, linear, item in data') or note $info;
        $result = Algorithm::AM::Result->new(
            excluded_data => [],
            given_excluded => 0,
            num_variables => 3,
            test_item => [qw(a b c)],
            test_spec => 'comment',
            test_outcome => 2,
            exclude_nulls => 0,
            probability => .5,
            count_method => 'squared',
            datacap => 40,
            test_in_data => 0,
        );

        $info = ${$result->config_info};
        $expected = <<'END_INFO';
+----------------------------+----------------+
| Option                     | Setting        |
+----------------------------+----------------+
| Given Context              | a b c, comment |
| Number of data items       | 40             |
| Data Inclusion Probability |  0.5           |
| Test Item Excluded         | no             |
| Total Excluded             |  0             |
| Nulls                      | include        |
| Gang                       | squared        |
| Number of active variables |  3             |
| Test item in data          | no             |
+----------------------------+----------------+
END_INFO
        is_string_nows($info, $expected,
            'given/nulls included, linear, item not in data, probability')
            or note $info;
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
        my $am = Algorithm::AM->new($project);
        my ($result) = $am->classify();
        my $stats = ${$result->statistical_summary};
        is_string_nows($stats,
            <<'END_STATS', 'statistical summary') or note $stats;
Statistical Summary
+---------+----------+------------+
| Outcome | Pointers | Percentage |
+---------+----------+------------+
| e       |  4       |  30.769%   |
| r       |  9       |  69.231%   |
+---------+----------+------------+
| Total   | 13       |            |
+---------+----------+------------+
Expected outcome: r
Correct outcome predicted.
END_STATS
        my $set = ${$result->analogical_set_summary};
        is_string_nows($set,
            <<'END_SET', 'analogical set') or note $set;
Analogical Set
Total Frequency = 13
+---------+---------------------+----------+------------+
| Outcome | Exemplar            | Pointers | Percentage |
+---------+---------------------+----------+------------+
| e       | myFirstCommentHere  | 4        |  30.769%   |
| r       | myThirdCommentHere  | 2        |  15.385%   |
| r       | myFourthCommentHere | 3        |  23.077%   |
| r       | myFifthCommentHere  | 4        |  30.769%   |
+---------+---------------------+----------+------------+
END_SET
        my $gang = ${$result->gang_summary(0)};
        is_string_nows($gang,
            <<'END_GANG', 'gang summary without items') or note $gang;
+------------+----------+-----------+---------+-------+
| Percentage | Pointers | Num Items | Outcome |       |
| Context    |          |           |         | 3 1 2 |
+------------+----------+-----------+---------+-------+
*******************************************************
|  61.538%   | 8        |           |         | 3 1   |
+------------+----------+-----------+---------+-------+
|  30.769%   | 4        | 1         | e       |       |
|  30.769%   | 4        | 1         | r       |       |
*******************************************************
|  23.077%   | 3        |           |         |   1 2 |
+------------+----------+-----------+---------+-------+
|  23.077%   | 3        | 1         | r       |       |
*******************************************************
|  15.385%   | 2        |           |         |     2 |
+------------+----------+-----------+---------+-------+
|  15.385%   | 2        | 1         | r       |       |
+------------+----------+-----------+---------+-------+
END_GANG
        $gang = ${$result->gang_summary(1)};
        is_string_nows($gang,
            <<'END_GANG', 'gang summary with items') or note $gang;
+------------+----------+-----------+---------+-------+---------------------+
| Percentage | Pointers | Num Items | Outcome |       | Item Comment        |
| Context    |          |           |         | 3 1 2 |                     |
+------------+----------+-----------+---------+-------+---------------------+
*****************************************************************************
|  61.538%   | 8        |           |         | 3 1   |                     |
+------------+----------+-----------+---------+-------+---------------------+
|  30.769%   | 4        | 1         | e       |       |                     |
|            |          |           |         | 3 1 0 | myFirstCommentHere  |
|  30.769%   | 4        | 1         | r       |       |                     |
|            |          |           |         | 3 1 1 | myFifthCommentHere  |
*****************************************************************************
|  23.077%   | 3        |           |         |   1 2 |                     |
+------------+----------+-----------+---------+-------+---------------------+
|  23.077%   | 3        | 1         | r       |       |                     |
|            |          |           |         | 2 1 2 | myFourthCommentHere |
*****************************************************************************
|  15.385%   | 2        |           |         |     2 |                     |
+------------+----------+-----------+---------+-------+---------------------+
|  15.385%   | 2        | 1         | r       |       |                     |
|            |          |           |         | 0 3 2 | myThirdCommentHere  |
+------------+----------+-----------+---------+-------+---------------------+
END_GANG
    };
    return;
}

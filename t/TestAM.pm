# provide some helper functions for use throughout the other test files
# helps to keep commonly-used data (chapter 3) in one place
package t::TestAM;
use strict;
use warnings;
use Algorithm::AM;
use Exporter::Easy (
    OK => [qw(
        chapter_3_project
        chapter_3_data
        chapter_3_test)]
);

# return a project pre-loaded with chapter 3 data
sub chapter_3_project {
    my $project = Algorithm::AM::Project->new();
    for my $datum(chapter_3_data()){
        $project->add_data(@$datum);
    }
    $project->add_test([qw(3 1 2)], 'test item spec', 'r');
    return $project;
}

# return a list of array refs containing the data from chapter 3
sub chapter_3_data {
    return (
        [[qw(3 1 0)], 'myFirstCommentHere', 'e'],
        [[qw(2 1 0)], 'mySecondCommentHere', 'r'],
        [[qw(0 3 2)], 'myThirdCommentHere', 'r'],
        [[qw(2 1 2)], 'myFourthCommentHere', 'r'],
        [[qw(3 1 1)], 'myFifthCommentHere', 'r']
    );
}

# return an array ref containing the test item used in chapter 3
sub chapter_3_test {
    return [[qw(3 1 2)], 'myCommentHere', 'r'];
}

1;

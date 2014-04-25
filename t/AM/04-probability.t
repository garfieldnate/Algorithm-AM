#test setting exemplar inclusion probability
use strict;
use warnings;
use Algorithm::AM;
use Test::More 0.88;
plan tests => 2;
use Test::NoWarnings;

my $project = Algorithm::AM::Project->new();
$project->add_data([qw(3 1 0)], 'myFirstCommentHere', 'e');
$project->add_test([qw(3 1 2)], 'myCommentHere', 'r');

my $am = Algorithm::AM->new($project, repeat => 2);
my ($result) = $am->classify(probability => .9);
#TODO: test this more explicitly, perhaps by overriding rand()
is($result->probability, .9, 'probability recorded in result')
    or note $result->probability;

#clean up the amcpresults file
unlink $project->results_path
	if -e $project->results_path;
# test repeat classification option
use strict;
use warnings;
use Algorithm::AM;
use Test::More 0.88;
plan tests => 2;
use Test::NoWarnings;

use FindBin qw($Bin);
use Path::Tiny;
use File::Slurp;

my $project = Algorithm::AM::Project->new();
$project->add_data([qw(3 1 0)], 'myFirstCommentHere', 'e');
$project->add_test([qw(3 1 2)], 'myCommentHere', 'r');

my $am = Algorithm::AM->new($project, repeat => 2);
my @results = $am->classify();
is(scalar @results, 2, 'exemplar is analyzed twice') or
    note scalar @results;

#clean up the amcpresults file
my $results_path = path($Bin, 'amcpresults');
unlink $results_path
    if -e $results_path;
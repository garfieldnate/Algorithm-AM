#Sanity test for classification- try the example from chapter 3 of the green book

use strict;
use warnings;
use Algorithm::AM;
# use AM::Parallel;
use Test::More 0.88;
plan tests => 5;
use Test::NoWarnings;
use Test::LongString;

use FindBin qw($Bin);
use Path::Tiny;
use File::Slurp;


my $project_path = path($Bin, 'data', 'chapter3');
my $results_path = path($project_path, 'amcpresults');
#clean up previous test runs
unlink $results_path
	if -e $results_path;

my $am = Algorithm::AM->new(
	$project_path,
	commas => 'no',
);
$am->classify();
my $results = read_file($results_path);
like_string($results,qr/e\s+4\s+30.769%\v+r\s+9\s+69.231%/, 'Chapter 3 data, counting pointers')
	or diag $results;
like_string($results,qr/Gang: squared/, 'Chapter 3 data, counting occurences')
    or diag $results;

#clean up the amcpresults file
unlink $results_path
	if -e $results_path;

$am->classify(linear => 1);
$results = read_file($results_path);
like_string($results,qr/e\s+2\s+28.571%\v+r\s+5\s+71.429%/, 'Chapter 3 data, counting occurences')
    or diag $results;
like_string($results,qr/Gang: linear/, 'Chapter 3 data, counting occurences')
    or diag $results;

#clean up the amcpresults file
unlink $results_path
	if -e $results_path;
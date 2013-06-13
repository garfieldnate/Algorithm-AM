#test inclusion/exclusion of givens
use strict;
use warnings;
use Algorithm::AM;
use Test::More 0.88;
plan tests => 3;
use Test::NoWarnings;
use Test::LongString;

use FindBin qw($Bin);
use Path::Tiny;
use File::Slurp;


my $project_path = path($Bin, 'data', 'chapter3_given');
my $results_path = path($project_path, 'amcpresults');
#clean up previous test runs
unlink $results_path
	if -e $results_path;

my $am = Algorithm::AM->new(
	$project_path,
	-commas => 'no',
	-given => 'exclude'
);
$am->classify();
my $results = read_file($results_path);
like_string($results,qr/e   4   30.769%\v+r   9   69.231%/, 'Exclude given')
	or diag $results;

#clean up the amcpresults file
unlink $results_path
	if -e $results_path;


$am->classify(-given => 'include');
$results = read_file($results_path);
like_string($results,qr/r\s+15\s+100.000%/, 'Include given')
	or diag $results;

#clean up the amcpresults file
unlink $results_path
	if -e $results_path;

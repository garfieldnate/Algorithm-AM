#test inclusion/exclusion of givens
use strict;
use warnings;
use Algorithm::AM;
use Test::More 0.88;
use Test::LongString;
use FindBin qw($Bin);
use Path::Tiny;
use File::Slurp;

plan tests => 5;

my $project_path = path($Bin, 'data', 'chapter3');
my $results_path = path($project_path, 'amcpresults');
#clean up previous test runs
unlink $results_path
	if -e $results_path;

my $am = Algorithm::AM->new(
	$project_path,
	-commas => 'no',
	-gangs => 'no'
);
$am->classify();
my $results = read_file($results_path);
unlike_string($results,qr/\sx\s/, q{'-gangs => no' doesn't list gangs})
	or diag $results;

#clean up the amcpresults file
unlink $results_path
	if -e $results_path;

$am->classify(-gangs => 'summary');
$results = read_file($results_path);
unlike_string($results, qr/3 1 0\s+myCommentHere/, q{'-gangs => summary' doesn't list gang exemplars})
	or diag $results;
like_string($results, qr/ 61.538%\s+8\s+3 1 2/, q{'-gangs => summary' lists gang effects})
	or diag $results;

#clean up the amcpresults file
unlink $results_path
	if -e $results_path;

$am->classify(-gangs => 'yes');
my $results = read_file($results_path);
like_string($results,qr/3 1 1\s+myCommentHere/, q{'-gangs => summary' lists gang exemplars})
	or diag $results;
like_string($results,qr/\s*23.077%\s+3\s+3 1 2/, q{'-gangs => summary' lists gang effects})
	or diag $results;

#clean up the amcpresults file
unlink $results_path
	if -e $results_path;

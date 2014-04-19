# test gang set printing.
use strict;
use warnings;
use Algorithm::AM;
use Test::More 0.88;
use Test::LongString;
plan tests => 7;
use Test::NoWarnings;
use Test::Warn;

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
	gangs => 'no'
);
$am->classify();
my $results = read_file($results_path);
unlike_string($results,qr/\sx\s/, q{'-gangs => no' doesn't list gangs})
	or note $results;

#clean up the amcpresults file
unlink $results_path
	if -e $results_path;

$am->classify(gangs => 'summary');
$results = read_file($results_path);
unlike_string($results, qr/3 1 0\s+myFirstCommentHere/,
    q{'-gangs => summary' doesn't list gang exemplars})
	or note $results;
like_string($results, qr/ 61.538%\s+8\s+3 1 2/, q{'-gangs => summary' lists gang effects})
	or note $results;

#clean up the amcpresults file
unlink $results_path
	if -e $results_path;

$am->classify(gangs => 'yes');
$results = read_file($results_path);
like_string($results,qr/3 1 1\s+myFifthCommentHere/, q{'-gangs => summary' lists gang exemplars})
	or note $results;
like_string($results,qr/\s*23.077%\s+3\s+3 1 2/, q{'-gangs => summary' lists gang effects})
	or note $results;

#clean up the amcpresults file
unlink $results_path
	if -e $results_path;

warning_is {
    Algorithm::AM->new(
        $project_path,
        commas => 'no',
        gangs => 'whatever'
    );
    } {carped => q<Failed to specify option 'gangs' correctly>},
    q<warning for bad 'gangs' parameter>;

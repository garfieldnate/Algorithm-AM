#test null handling
use strict;
use warnings;
use Algorithm::AM;
use Test::More 0.88;
plan tests => 5;
use Test::NoWarnings;
use Test::LongString;

use FindBin qw($Bin);
use Path::Tiny;
use File::Slurp;


my $project_path = path($Bin, 'data', 'chapter3_null_feat');
my $results_path = path($project_path, 'amcpresults');
#clean up previous test runs
unlink $results_path
	if -e $results_path;

my $am = Algorithm::AM->new(
	$project_path,
	commas => 'no',
	exclude_nulls => 1,
);
$am->classify();
my $results = read_file($results_path);
like_string($results,qr/e\s+3\s+30.000%\v+r\s+7\s+70.000%/,
    'Results with exclude nulls')
	or diag $results;
like_string($results, qr/Nulls: exclude/,
    'Printing with exclude nulls')
    or diag $results;

#clean up the amcpresults file
unlink $results_path
	if -e $results_path;


$am->classify(exclude_nulls => 0);
$results = read_file($results_path);
like_string($results,qr/r\s+5\s+100.000%/, 'Include nulls')
	or diag $results;
like_string($results, qr/Nulls: include/,
    'Printing with exclude nulls')
    or diag $results;

#clean up the amcpresults file
unlink $results_path
	if -e $results_path;
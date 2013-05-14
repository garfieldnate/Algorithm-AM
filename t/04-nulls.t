#test null handling
use strict;
use warnings;
use Algorithm::AM;
use Test::More 0.88;
use Test::LongString;
use FindBin qw($Bin);
use Path::Tiny;
use File::Slurp;

plan tests => 2;

my $project_path = path($Bin, 'data', 'chapter3_null_feat');
my $results_path = path($project_path, 'amcpresults');
#clean up previous test runs
unlink $results_path
	if -e $results_path;

my $am = Algorithm::AM->new(
	$project_path,
	-commas => 'no',
	-nulls => 'exclude'
);
$am->classify();
my $results = read_file($results_path);
like_string($results,qr/e\s+3\s+30.000%\v+r\s+7\s+70.000%/, 'Exclude nulls')
	or diag $results;

#clean up the amcpresults file
unlink $results_path
	if -e $results_path;


$am->classify(-nulls => 'include');
my $results = read_file($results_path);
like_string($results,qr/r\s+5\s+100.000%/, 'Include nulls')
	or diag $results;

#clean up the amcpresults file
unlink $results_path
	if -e $results_path;
#test setting exemplar inclusion probability
use strict;
use warnings;
use Algorithm::AM;
use Test::More 0.88;
plan tests => 2;
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
	-commas => 'no',
	-probability => .9
);
$am->classify();
my $results = read_file($results_path);
like_string($results, qr/Probability of including any one data item: 0.9/, 'probability noted in output')
	or diag $results;

#clean up the amcpresults file
unlink $results_path
	if -e $results_path;
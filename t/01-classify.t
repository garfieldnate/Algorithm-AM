#Sanity test for classification- try the example from chapter 3 of the greenbook

use strict;
use warnings;
use Algorithm::AM;
# use AM::Parallel;
use Test::More 0.88;
use Test::LongString;
use FindBin qw($Bin);
use Path::Tiny;
use File::Slurp;

plan tests => 1;


my $results_path = path($Bin, 'data', 'chapter3', 'amcpresults');
#clean up previous test runs
unlink $results_path
	if -e $results_path;

my $am = Algorithm::AM->new(
# my $am = AM::Parallel->new(
	path($Bin, 'data', 'chapter3'),
	-commas => 'no',
	# -given => 'exclude',
	# -gangs => 'yes',
);
$am->();
my $results = read_file($results_path);
like_string($results,qr/e   4   30.769%\v+r   9   69.231%/, 'Correct results with chapter3 data')
	or diag $results;

#clean up the amcpresults file
unlink $results_path
	if -e $results_path;
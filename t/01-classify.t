#Sanity test for classification- try the example from chapter 3 of the greenbook

use strict;
use warnings;
use Algorithm::AM;
# use AM::Parallel;
use Test::More;
use FindBin qw($Bin);
use Path::Tiny;

plan tests => 1;
my $am = Algorithm::AM->new(
# my $am = AM::Parallel->new(
	path($Bin, 'chapter3', 'simple'),
	-commas => 'no',
	-given => 'exclude',
	# -gangs => 'yes',
);
$am->();
ok(1);

#the data from chapter3 yield:
#e   4   30.769%
#r   9   69.231%

#clean up the amcpresults file
my $results_path = path($Bin, 'data', 'amcpresults');
unlink $results_path
	if -e $results_path;
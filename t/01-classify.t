#basic test file

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
	path($Bin, 'data', 'simple'),
	-commas => 'no',
	-given => 'exclude',
	-gangs => 'yes',
);
$am->();
ok(1);

#clean up the amcpresults file
my $results_path = path($Bin, 'data', 'amcpresults');
unlink $results_path
	if -e $results_path;
#test printing/not printing of analogical set
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

my $project_path = path($Bin, 'data', 'chapter3');
my $results_path = path($project_path, 'amcpresults');
#clean up previous test runs
unlink $results_path
	if -e $results_path;

my $am = Algorithm::AM->new(
	$project_path,
	commas => 'no',
	skipset => 0
);
$am->classify();
my $results = read_file($results_path);
# analogical effects are printed with exemplars grouped
# by containing context
my $set = qr/
    r\s+myThirdCommentHere\s+2\s+15.385%\v+
    -----\v+
    r\s+myFourthCommentHere\s+3\s+23.077%\v+
    -----\v+
    r\s+myFifthCommentHere\s+4\s+30.769%\v+
    e\s+myFirstCommentHere\s+4\s+30.769%\v+
    -----
/x;
like_string($results, $set, q{'skipset => 0' prints the analogical set})
	or note $results;

#clean up the amcpresults file
unlink $results_path
	if -e $results_path;

$am->classify(skipset => 1);
$results = read_file($results_path);
unlike_string($results, $set, q{'skipset => 1' doesn't print the analogical set})
	or note $results;

#clean up the amcpresults file
unlink $results_path
	if -e $results_path;

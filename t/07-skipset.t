#test printing/not printing of analogical set
use strict;
use warnings;
use Algorithm::AM;
use Test::More 0.88;
use Test::LongString;
use FindBin qw($Bin);
use Path::Tiny;
use File::Slurp;

plan tests => 2;

my $project_path = path($Bin, 'data', 'chapter3');
my $results_path = path($project_path, 'amcpresults');
#clean up previous test runs
unlink $results_path
	if -e $results_path;

my $am = Algorithm::AM->new(
	$project_path,
	-commas => 'no',
	-skipset => 'no'
);
$am->classify();
my $results = read_file($results_path);
my $set = qr/e\s+myCommentHere\s+4\s+30.769%\v+
r\s+myCommentHere\s+2\s+15.385%\v+
r\s+myCommentHere\s+3\s+23.077%\v+
r\s+myCommentHere\s+4\s+30.769%/x;
like_string($results, $set, q{'-skipset => no' prints the analogical set})
	or diag $results;

#clean up the amcpresults file
unlink $results_path
	if -e $results_path;

$am->classify(-skipset => 'yes');
$results = read_file($results_path);
unlike_string($results, $set, q{'-skipset => yes' doesn't print the analogical set})
	or diag $results;

#clean up the amcpresults file
unlink $results_path
	if -e $results_path;

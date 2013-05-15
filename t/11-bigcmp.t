#test exported variables and methods
use strict;
use warnings;
use Test::More 0.88;
plan tests => 5;
use Algorithm::AM;
use FindBin qw($Bin);
use Path::Tiny;
use Data::Dumper;

use vars qw(@sum);
use subs qw(bigcmp);

my $project_path = path($Bin, 'data', 'chapter3');
my $results_path = path($project_path, 'amcpresults');

my $am = Algorithm::AM->new(
	$project_path,
	-commas => 'no',
);
$am->classify(
	-endhook => \&endhook,
);

#cleanup amcpresults file
unlink $results_path
	if -e $results_path;

sub endhook {
	test_bigcmp();
}

#compare the pointer counts, which should be 4 and 9 for the chapter 3 data
sub test_bigcmp {
	my ($a, $b) = @sum[1,2];
	is("$a", '4', 'compare 9');
	is("$b", '9', 'and 4');
	is(bigcmp($a, $b), -1, '4 is smaller than 9');
	is(bigcmp($b, $a), 1, '9 is bigger than 4');
	is(bigcmp($a, $a), 0, '9 is equal to 9');
}
#test exported variables and methods
use strict;
use warnings;
use Test::More 0.88;
plan tests => 6;
use Test::NoWarnings;
use Algorithm::AM;

use vars qw(@sum);
use subs qw(bigcmp);

my @data = (
	[[qw(3 1 0)], 'myFirstCommentHere', 'e', undef],
	[[qw(2 1 0)], '210', 'r', undef],
	[[qw(0 3 2)], 'myThirdCommentHere', 'r', undef],
	[[qw(2 1 2)], 'myFourthCommentHere', 'r', undef],
	[[qw(3 1 1)], 'myFifthCommentHere', 'r', undef]
);
my $project = Algorithm::AM::Project->new();
for my $datum(@data){
    $project->add_data(@$datum);
}
$project->add_test([qw(3 1 2)], 'myCommentHere', 'r');

my $am = Algorithm::AM->new(
	$project,
	commas => 'no',
);
$am->classify(
	endhook => \&endhook,
);

#cleanup amcpresults file
unlink $project->results_path
	if -e $project->results_path;

sub endhook {
	test_bigcmp(@_);
}

#compare the pointer counts, which should be 4 and 9 for the chapter 3 data
sub test_bigcmp {
	my ($am, $data) = @_;
	my ($a, $b) = @{$am->{sum}}[1,2];
	is("$a", '4', 'compare 9');
	is("$b", '9', 'and 4');
	is(bigcmp($a, $b), -1, '4 is smaller than 9');
	is(bigcmp($b, $a), 1, '9 is bigger than 4');
	is(bigcmp($a, $a), 0, '9 is equal to 9');
}

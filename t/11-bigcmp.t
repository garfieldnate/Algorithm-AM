#test exported variables and methods
use strict;
use warnings;
use Test::More 0.88;
plan tests => 6;
use Test::NoWarnings;
use Algorithm::AM;
use t::TestAM qw(chapter_3_project);

use vars qw(@sum);
use subs qw(bigcmp);

my $project = chapter_3_project();

my $am = Algorithm::AM->new(
	$project,
	commas => 'no',
);
$am->classify(
	endhook => \&endhook,
);

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

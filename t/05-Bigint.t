#test exported variables and methods
use strict;
use warnings;
use Test::More 0.88;
plan tests => 6;
use Test::NoWarnings;
use Algorithm::AM;
use Algorithm::AM::Batch;
use t::TestAM qw(chapter_3_train chapter_3_test);

use vars qw(@sum);
use subs qw(bigcmp);

my $train = chapter_3_train();
my $test = chapter_3_test();

my $batch = Algorithm::AM::Batch->new(
    training_set => $train,
    test_set => $test
);
$batch->classify_all(
	endhook => \&endhook,
);

sub endhook {
	test_bigcmp(@_);
}

#compare the pointer counts, which should be 4 and 9 for the chapter 3 data
sub test_bigcmp {
	my ($am, $result) = @_;
	my %scores = %{ $result->scores };
	my ($a, $b) = @scores{'e','r'};
	is("$a", '4', 'compare 9');
	is("$b", '9', 'and 4');
	is(bigcmp($a, $b), -1, '4 is smaller than 9');
	is(bigcmp($b, $a), 1, '9 is bigger than 4');
	is(bigcmp($a, $a), 0, '9 is equal to 9');
}

#test exported variables and methods
use strict;
use warnings;
use feature qw(state);
use Test::More 0.88;
use Test::NoWarnings;
use t::TestAM qw(chapter_3_train chapter_3_test);

my $train = chapter_3_train();
my $test = chapter_3_test();

use Algorithm::AM;

# Tests are run by the hooks passed into the classify() method.
# Each hook contains one test with several subtests. Each is called
# this many times:
my %hook_calls = (
	beginhook => 1,
	begintesthook => 2,
	beginrepeathook => 4,
	endrepeathook => 4,
	datahook => 20,
	endtesthook => 2,
	endhook => 1,
);
my $total_calls = 0;
$total_calls += $_ for values %hook_calls;
# +1 for Test::NoWarnings
plan tests => $total_calls + 1;

# store number of tests run by each method so we
# can plan subtests
my %tests_per_sub = (
	test_beginning_vars => 2,
	test_item_vars => 3,
	test_iter_vars => 3,
	test_end_iter_vars => 1,
	test_end_vars => 4
);
# store methods for choosing to what run in make_hook
my %test_subs = (
	test_beginning_vars => \&test_beginning_vars,
	test_item_vars => \&test_item_vars,
	test_iter_vars => \&test_iter_vars,
	test_end_iter_vars => \&test_end_iter_vars,
	test_end_vars => \&test_end_vars
);


$train = chapter_3_train();
$test = chapter_3_test();
$test->add_item(
	features => [qw(3 1 3)],
	comment => 'second test item',
	class => 'e',
);

my $am = Algorithm::AM->new(
	train => $train,
	test => $test,
	repeat => 2,
	probability => 1,
);
$am->classify(
	beginhook => make_hook(
		'beginhook',
		'test_beginning_vars'
	),
	begintesthook => make_hook(
		'begintesthook',
		'test_beginning_vars',
		'test_item_vars'),
	beginrepeathook => make_hook(
		'beginrepeathook',
		'test_beginning_vars',
		'test_item_vars',
		'test_iter_vars'),
	datahook => make_hook(
		'datahook',
		'test_beginning_vars',
		'test_item_vars',
		'test_iter_vars'),
	endrepeathook => make_hook(
		'endrepeathook',
		'test_beginning_vars',
		'test_item_vars',
		'test_iter_vars',
		'test_end_iter_vars'),
	endtesthook => make_hook(
		'endtesthook',
		'test_beginning_vars',
		'test_item_vars',
		'test_end_iter_vars'),
	endhook => make_hook(
		'endhook',
		'test_beginning_vars',
		'test_end_vars'
	),
);

# make a hook which runs the given test subs in a single subtest.
# Pass on the arguments passed to the hook at classification time.
sub make_hook {
	my ($name, @subs) = @_;
	return sub {
		my (@args) = @_;
		subtest $name => sub {
			my $plan = 0;
			$plan += $tests_per_sub{$_} for @subs;
			plan tests => $plan;
			$test_subs{$_}->(@args) for @subs;
		};
		# true return value is needed by datahook to signal
		# that data should be considered during classification
		return 1;
	};
}

#check vars available from beginning to end of classification
sub test_beginning_vars {
	my ($am) = @_;
	isa_ok($am, 'Algorithm::AM');
	is($am->training_set->size, 5,
		"training set in \$am");
	return;
}

# Check variables provided before each test
# There are two items, 312 and 313, marked with
# different specs and outcomes. Check each one.
sub test_item_vars {
	my ($am, $test_item) = @_;
	my ($outcome, $variables, $spec) = @$test_item;

	ok($outcome eq 'r' || $outcome eq 'e', 'test outcome');
	if($outcome eq 'e'){
		like(
			$spec,
			qr/second test item$/,
			'test spec'
		);
		is_deeply($variables, [3,1,3], 'test variables')
			or note explain $variables;
	}else{
		like(
			$spec,
			qr/test item spec$/,
			'test spec'
		);
		is_deeply($variables, [3,1,2], 'test variables')
			or note explain $variables;
	}
	return;
}

# Test variables available for each iteration
sub test_iter_vars {
	my ($am, $test, $iter_data) = @_;
	ok(
		$iter_data->{pass} == 0 || $iter_data->{pass} == 1,
		'$pass- only do 2 passes of the data');
	is($am->{probability}, 1,
		'$probability is 1 by default');
	is($iter_data->{datacap}, 5,
		'$datacap is 5, the number of exemplars');
	return;
}

# Test variables provided after an iteration is finished
sub test_end_iter_vars {
	my ($am, $test, $iter_data, $result) = @_;
	my ($outcome, $variables, $spc) = @$test;

	if($outcome eq 'e'){
		is_deeply($result->scores, {e => '4', r => '4'},
			'outcome scores');
	}else{
		is_deeply($result->scores, {e => '4', r => '9'},
			'outcomes scores');
	}
	return;
}

# Test variables provided after all iterations are finished
sub test_end_vars {
	my ($am, @results) = @_;

	is_deeply($results[0]->scores, {e => '4', r => '9'},
		'scores for first result');
	is_deeply($results[1]->scores, {e => '4', r => '9'},
		'scores for second result');
	is_deeply($results[2]->scores, {e => '4', r => '4'},
		'scores for third result');
	is_deeply($results[3]->scores, {e => '4', r => '4'},
		'scores for fourth result');
	return;
}

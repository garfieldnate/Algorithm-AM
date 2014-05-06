#test exported variables and methods
use strict;
use warnings;
use feature qw(state);
use Test::More 0.88;
use Test::NoWarnings;
use t::TestAM qw(
	chapter_3_data
	chapter_3_project
	chapter_3_test
);
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


my $project = chapter_3_project();
$project->add_test([qw(3 1 3)], 'e', 'second test item');

my $am = Algorithm::AM->new(
	$project,
	repeat => 2,
	probability => 1,
);
$am->classify(
	beginhook => make_hook('beginhook',
		'test_beginning_vars'),
	begintesthook => make_hook('begintesthook',
		'test_beginning_vars',
		'test_item_vars'),
	beginrepeathook => make_hook('begintesthook',
		'test_beginning_vars',
		'test_item_vars',
		'test_iter_vars'),
	datahook => make_hook('begintesthook',
		'test_beginning_vars',
		'test_item_vars',
		'test_iter_vars'),
	endrepeathook => make_hook('begintesthook',
		'test_beginning_vars',
		'test_item_vars',
		'test_iter_vars',
		'test_end_iter_vars'),
	endtesthook => make_hook('begintesthook',
		'test_beginning_vars',
		'test_item_vars',
		'test_end_iter_vars'),
	endhook => make_hook('endhook',
		'test_beginning_vars',
		'test_end_vars'),
);

# make a hook which runs the given test subs in a single subtest.
# Pass on the hook name to test subs (which print it) along with
# the arguments passed to the hook at classification time.
sub make_hook {
	my ($name, @subs) = @_;
	return sub {
		my (@args) = @_;
		subtest $name => sub {
			my $plan = 0;
			$plan += $tests_per_sub{$_} for @subs;
			plan tests => $plan;
			$test_subs{$_}->($name, @args) for @subs;
		};
		# true return value is needed by datahook to signal
		# that data should be considered during classification
		return 1;
	};
}

#check vars available from beginning to end of classification
sub test_beginning_vars {
	my ($hook_name, $am) = @_;
	isa_ok($am, 'Algorithm::AM', "$hook_name: \$am");
	is($am->get_project->num_exemplars, 5,
		"$hook_name: \$am has correct project");
	return;
}

# Check variables provided before each test
# There are two items, 312 and 313, marked with
# different specs and outcomes. Check each one.
sub test_item_vars {
	my ($hook, $am, $test_item) = @_;
	my ($outcome, $variables, $spec) = @$test_item;

	ok($outcome eq 'r' || $outcome eq 'e',
		$hook . ': test outcome');
	if($outcome eq 'e'){
		like(
			$spec,
			qr/second test item$/,
			$hook . ': test spec'
		);
		is_deeply($variables, [3,1,3], $hook . ': test variables')
			or note explain $variables;
	}else{
		like(
			$spec,
			qr/test item spec$/,
			$hook . ': test spec'
		);
		is_deeply($variables, [3,1,2], $hook . ': test variables')
			or note explain $variables;
	}
	return;
}

# Test variables available for each iteration
sub test_iter_vars {
	my ($hook_name, $am, $test, $data) = @_;
	ok(
		${$data->{pass}} == 0 || ${$data->{pass}} == 1,
		$hook_name . ': $pass- only do 2 passes of the data');
	is($am->{probability}, 1,
		$hook_name . ': $probability is 1 by default');
	is($data->{datacap}, 5,
		$hook_name . ': $datacap is 5, the number of exemplars');
	return;
}

# Test variables provided after an iteration is finished
sub test_end_iter_vars {
	my ($hook_name, $am, $test, $data, $result) = @_;
	my ($outcome, $variables, $spc) = @$test;

	if($outcome eq 'e'){
		is_deeply($result->scores, {e => '4', r => '4'},
			$hook_name . ': outcome scores');
	}else{
		is_deeply($result->scores, {e => '4', r => '9'},
			$hook_name . ': outcomes scores');
	}
	return;
}

# Test variables provided after all iterations are finished
sub test_end_vars {
	my ($hook_name, $am, @results) = @_;

	is_deeply($results[0]->scores, {e => '4', r => '9'},
		$hook_name . ': scores for first result');
	is_deeply($results[1]->scores, {e => '4', r => '9'},
		$hook_name . ': scores for second result');
	is_deeply($results[2]->scores, {e => '4', r => '4'},
		$hook_name . ': scores for third result');
	is_deeply($results[3]->scores, {e => '4', r => '4'},
		$hook_name . ': scores for fourth result');
	return;
}

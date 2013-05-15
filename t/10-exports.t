#test exported variables and methods
use strict;
use warnings;
use feature qw(state);
use Test::More 0.88;
#test_beginning_vars contains five tests and is run for every handler (34 times)
#test_item_vars contains three tests and is run for most handlers (32 times)
#test_iter_vars contains three tests and is run for most handlers (28 times)
#test_end_vars contains three tests and is run by two handlers (total 6 times)
plan tests => 5*34 + 3*32 + 3*28 + 3*6;
use Algorithm::AM;
use FindBin qw($Bin);
use Path::Tiny;

use vars qw(

	@outcomelist
	%outcometonum
	@outcome
	@data
	@spec

	$curTestOutcome
	@curTestItem
	$curTestSpec

	$pass
	$probability
	$datacap

	@sum
	$pointertotal
	$pointermax
);

my $project_path = path($Bin, 'data', 'chapter3_multi_test');
my $results_path = path($project_path, 'amcpresults');

my $am = Algorithm::AM->new(
	$project_path,
	-commas => 'no',
	-repeat => 2,
	-probability => 1,
);
$am->classify(
	-beginhook => \&beginhook,
	-begintesthook => \&begintesthook,
	-beginrepeathook => \&beginrepeathook,
	-datahook => \&datahook,
	-endrepeathook => \&endrepeathook,
	-endtesthook => \&endtesthook,
	-endhook => \&endhook,
);

#cleanup amcpresults file
unlink $results_path
	if -e $results_path;

sub beginhook {
	test_beginning_vars('beginhook');
}

sub begintesthook {
	test_beginning_vars('begintesthook');
	test_item_vars('begintesthook');
}

sub beginrepeathook {
	test_beginning_vars('beginrepeathook');
	test_item_vars('beginrepeathook');
	test_iter_vars('beginrepeathook');
}

sub datahook {
	test_beginning_vars('datahook');
	test_item_vars('datahook');
	test_iter_vars('datahook');
	return 1;
}
sub endrepeathook {
	test_beginning_vars('endrepeathook');
	test_item_vars('endrepeathook');
	test_iter_vars('endrepeathook');
	test_end_vars('endrepeathook');
}

sub endtesthook {
	test_beginning_vars('endtesthook');
	test_item_vars('endtesthook');
	test_end_vars('endtesthook');
}

sub endhook {
	test_beginning_vars('endhook');
}

#check vars available from beginning to end of classification
sub test_beginning_vars {
	my ($hook_name) = @_;
	#TODO: export something better than this; why should we have to skip 0?
	is_deeply(\@outcomelist, ['','e','r'], $hook_name . ': @outcomelist')
		or note explain \@outcomelist;
	#why should we need this?
	is_deeply(\%outcometonum, {'e' => 1, 'r' => 2}, $hook_name . ': %outcometonum')
		or note explain \@outcomelist;
	#why not [e,r,r,r,r]?
	is_deeply(\@outcome, [1,2,2,2,2], $hook_name . ': @outcome')
		or note explain \@outcome;
	is_deeply(
		\@data,
		[
			['3', '1', '0'],
			['2', '1', '0'],
			['0', '3', '2'],
 	     	['2', '1', '2'],
          	['3', '1', '1']
        ],
        $hook_name . ': @data'
    )
		or note explain \@data;
	is_deeply(\@spec, [('myCommentHere') x 5], $hook_name . ': @spec')
		or note explain \@spec;
}

#check vars available per test
#there are two items, 312 and 313, marked with different specs and outcomes
#check the spec, outcome, and feature variables
sub test_item_vars {
	my ($hook) = @_;

	ok($curTestOutcome == 2 || $curTestOutcome == 1, $hook . ': $curTestOutcome');
	if($curTestOutcome == 2){
		like(
			$curTestSpec,
			qr/first test item$/,
			$hook . ': $curTestSpec'
		);

		is_deeply(\@curTestItem, [3,1,3], $hook . ': @curTestItem')
			or print $curTestSpec;
	}else{
		like(
			$curTestSpec,
			qr/second test item$/,
			$hook . ': $curTestSpec'
		);
		is_deeply(\@curTestItem, [3,1,2], $hook . ': @curTestItem')
			or print $curTestSpec;
	}
}

#test variables available per iteration
sub test_iter_vars {
	my ($hook_name) = @_;
	ok($pass == 0 || $pass == 1, $hook_name . ': $pass- only do 2 passes of the data');
	is($probability, 1, $hook_name . ': $probability- 1 by default');
	is($datacap, 5, $hook_name . ': $datacap is 5, the number of exemplars');
}

#test setting of vars for classification results
sub test_end_vars {
	my ($hook_name) = @_;
	my $subtotals = [@sum[1,2]];
	if($curTestOutcome == 2){
		is_deeply($subtotals, [4, 4], $hook_name . ': @sum');
		is($pointertotal, 8, $hook_name . ': $pointertotal');
		is($pointermax, 4, $hook_name . ': $pointermax');
	}else{
		is_deeply($subtotals, [4, 9], $hook_name . ': correct subtotals');
		is($pointertotal, 13, $hook_name . ': $pointertotal');
		is($pointermax, 9, $hook_name . ': $pointermax');
	}
}

#test exported variables and methods
use strict;
use warnings;
use feature qw(state);
use Test::More 0.88;
#test_beginning_vars contains five tests and is run for every handler (34 times)
#test_item_vars contains three tests and is run for most handlers (32 times)
#test_iter_vars contains three tests and is run for most handlers (28 times)
#test_end_vars contains three tests and is run by two handlers (total 6 times)
#1 more for Test::NoWarnings
plan tests => 5*34 + 3*32 + 3*28 + 3*6 + 1;
use Test::NoWarnings;
use Algorithm::AM;
use FindBin qw($Bin);
use Path::Tiny;

my $project_path = path($Bin, 'data', 'chapter3_multi_test');
my $results_path = path($project_path, 'amcpresults');

my $am = Algorithm::AM->new(
	$project_path,
	-commas => 'no',
	repeat => 2,
	probability => 1,
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
	test_beginning_vars('beginhook', @_);
}

sub begintesthook {
	test_beginning_vars('begintesthook', @_);
	test_item_vars('begintesthook', @_);
}

sub beginrepeathook {
	test_beginning_vars('beginrepeathook', @_);
	test_item_vars('beginrepeathook', @_);
	test_iter_vars('beginrepeathook', @_);
}

sub datahook {
	#$_[0] is $i
	test_beginning_vars('datahook', @_);
	test_item_vars('datahook', @_);
	test_iter_vars('datahook', @_);
	return 1;
}

sub endrepeathook {
	test_beginning_vars('endrepeathook', @_);
	test_item_vars('endrepeathook', @_);
	test_iter_vars('endrepeathook', @_);
	test_end_vars('endrepeathook', @_);
}

sub endtesthook {
	test_beginning_vars('endtesthook', @_);
	test_item_vars('endtesthook', @_);
	test_end_vars('endtesthook', @_);
}

sub endhook {
	test_beginning_vars('endhook', @_);
}

#check vars available from beginning to end of classification
sub test_beginning_vars {
	my ($hook_name, $am, $data) = @_;
	#TODO: export something better than this; why should we have to skip 0?
	is_deeply($data->{outcomelist}, ['','e','r'], $hook_name . ': @outcomelist')
		or note explain $data->{outcomelist};
	#why should we need this?
	is_deeply($data->{outcometonum}, {'e' => 1, 'r' => 2}, $hook_name . ': %outcometonum')
		or note explain $data->{outcometonum};
	#why not [e,r,r,r,r]?
	is_deeply($data->{outcome}, [1,2,2,2,2], $hook_name . ': @outcome')
		or note explain $data->{outcome};
	is_deeply(
		$data->{data},
		[
			['3', '1', '0'],
			['2', '1', '0'],
			['0', '3', '2'],
 	     	['2', '1', '2'],
          	['3', '1', '1']
        ],
        $hook_name . ': @data'
    )
		or note explain $data->{data};
	is_deeply($data->{spec}, [('myCommentHere') x 5], $hook_name . ': @spec')
		or note explain $data->{spec};
}

#check vars available per test
#there are two items, 312 and 313, marked with different specs and outcomes
#check the spec, outcome, and feature variables
sub test_item_vars {
	my ($hook, $am, $data) = @_;

	ok(${$data->{curTestOutcome}} == 2 || ${$data->{curTestOutcome}} == 1,
		$hook . ': $curTestOutcome');
	if(${$data->{curTestOutcome}} == 2){
		like(
			$data->{curTestSpec},
			qr/first test item$/,
			$hook . ': $curTestSpec'
		);

		is_deeply($data->{curTestItem}, [3,1,3], $hook . ': @{ $data->{curTestItem} }')
			or note explain $data->{curTestItem};
	}else{
		like(
			$data->{curTestSpec},
			qr/second test item$/,
			$hook . ': $curTestSpec'
		);
		is_deeply($data->{curTestItem}, [3,1,2], $hook . ': @{ $data->{curTestItem} }')
			or note explain $data->{curTestItem};
	}
}

#test variables available per iteration
sub test_iter_vars {
	my ($hook_name, $am, $data) = @_;
	ok(
		${$data->{pass}} == 0 || ${$data->{pass}} == 1,
		$hook_name . ': $pass- only do 2 passes of the data');
	is($am->{probability}, 1, $hook_name . ': $probability- 1 by default');
	is($data->{datacap}, 5, $hook_name . ': $datacap is 5, the number of exemplars');
}

#test setting of vars for classification results
sub test_end_vars {
	my ($hook_name, $am, $data) = @_;
	my $subtotals = [@{$data->{sum}}[1,2]];
	if(${$data->{curTestOutcome}} == 2){
		is_deeply($subtotals, ['4', '4'], $hook_name . ': @sum');
		is(${$data->{pointertotal}}, '8', $hook_name . ': $pointertotal');
		is($data->{pointermax}, '4', $hook_name . ': $pointermax');
	}else{
		is_deeply($subtotals, ['4', '9'], $hook_name . ': correct subtotals');
		is(${$data->{pointertotal}}, '13', $hook_name . ': $pointertotal');
		is($data->{pointermax}, '9', $hook_name . ': $pointermax');
	}
}

#test exported variables and methods
use strict;
use warnings;
use feature qw(state);
use Test::More 0.88;
plan tests => 5*34 + 3;
use Algorithm::AM;
use FindBin qw($Bin);
use Path::Tiny;
use Data::Section::Simple qw(get_data_section);
use Data::Dumper;

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

my $current_data = eval get_data_section('item_vars');
is_deeply(log_item_vars(), $current_data, 'item variables maintained correctly')
	or note explain log_item_vars();

my $iter_data = eval get_data_section('iter_vars');
is_deeply(log_iter_vars(), $iter_data, 'iteration variables maintained correctly')
	or note explain log_iter_vars();

my $end_data = eval get_data_section('end_vars');
is_deeply(log_end_vars(), $end_data, 'end variables maintained correctly')
	or note explain log_end_vars();

sub beginhook {
	# say 'beginhook';
	test_beginning_vars();
}

sub begintesthook {
	# say 'begintesthook';
	test_beginning_vars();
	log_item_vars('begintesthook');
}

sub beginrepeathook {
	# say 'beginrepeathook';
	test_beginning_vars();
	log_item_vars('beginrepeathook');
	log_iter_vars('beginrepeathook');
}

sub datahook {
	# say 'datahook';
	test_beginning_vars();
	log_item_vars('datahook');
	log_iter_vars('datahook');
	1;
}
sub endrepeathook {
	# say 'endrepeathook';
	test_beginning_vars();
	log_item_vars('endrepeathook');
	log_iter_vars('endrepeathook');
	log_end_vars('endrepeathook');
}

sub endtesthook {
	# say 'endtesthook';
	test_beginning_vars();
	log_item_vars('endtesthook');
	log_end_vars('endtesthook');
}

sub endhook {
	# say 'endhook';
	test_beginning_vars();
	log_end_vars('endhook');
}

sub test_beginning_vars {
	#TODO: export something better than this; why should we have to skip 0?
	is_deeply(\@outcomelist, ['','e','r'], '@outcomelist')
		or note explain \@outcomelist;
	#why should we need this?
	is_deeply(\%outcometonum, {'e' => 1, 'r' => 2}, '%outcometonum')
		or note explain \@outcomelist;
	#why not [e,r,r,r,r]?
	is_deeply(\@outcome, [1,2,2,2,2], '@outcome')
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
        '@data'
    )
		or note explain \@data;
	is_deeply(\@spec, [('myCommentHere') x 5], '@spec')
		or note explain \@spec;
}

sub log_item_vars {
	state @log;
	my ($hook) = @_;
	return \@log
		unless $hook;
	push @log, {
		hook => $hook,
		outcome =>	$curTestOutcome,
		data => join(':', @curTestItem),
		spec => $curTestSpec,
	};
	return;
}

sub log_iter_vars {
	state @log;
	my ($hook) = @_;
	return \@log
		unless $hook;
	push @log, {
		hook => $hook,
		probability => $probability,
		pass => $pass,
		datacap => $datacap
	};
	return;
}

sub log_end_vars {
	state @log;
	my ($hook) = @_;
	return \@log
		unless $hook;
	push @log, {
		hook 		=> $hook,
		subtotals	=>	join( ':', @sum[1,2]),
		total => "$pointertotal",
		max => "$pointermax",
	};
	return;
}

__DATA__
@@ item_vars
[
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:3',
    'hook' => 'begintesthook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:3',
    'hook' => 'beginrepeathook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:3',
    'hook' => 'datahook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:3',
    'hook' => 'datahook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:3',
    'hook' => 'datahook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:3',
    'hook' => 'datahook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:3',
    'hook' => 'datahook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:3',
    'hook' => 'endrepeathook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:3',
    'hook' => 'beginrepeathook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:3',
    'hook' => 'datahook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:3',
    'hook' => 'datahook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:3',
    'hook' => 'datahook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:3',
    'hook' => 'datahook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:3',
    'hook' => 'datahook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:3',
    'hook' => 'endrepeathook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:3',
    'hook' => 'endtesthook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:2',
    'hook' => 'begintesthook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:2',
    'hook' => 'beginrepeathook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:2',
    'hook' => 'datahook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:2',
    'hook' => 'datahook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:2',
    'hook' => 'datahook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:2',
    'hook' => 'datahook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:2',
    'hook' => 'datahook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:2',
    'hook' => 'endrepeathook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:2',
    'hook' => 'beginrepeathook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:2',
    'hook' => 'datahook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:2',
    'hook' => 'datahook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:2',
    'hook' => 'datahook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:2',
    'hook' => 'datahook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:2',
    'hook' => 'datahook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:2',
    'hook' => 'endrepeathook'
  },
  {
    'spec' => 'myCommentHere',
    'outcome' => 2,
    'data' => '3:1:2',
    'hook' => 'endtesthook'
  }
]

@@ iter_vars
[
  {
    'pass' => 0,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'beginrepeathook'
  },
  {
    'pass' => 0,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'datahook'
  },
  {
    'pass' => 0,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'datahook'
  },
  {
    'pass' => 0,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'datahook'
  },
  {
    'pass' => 0,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'datahook'
  },
  {
    'pass' => 0,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'datahook'
  },
  {
    'pass' => 0,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'endrepeathook'
  },
  {
    'pass' => 1,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'beginrepeathook'
  },
  {
    'pass' => 1,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'datahook'
  },
  {
    'pass' => 1,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'datahook'
  },
  {
    'pass' => 1,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'datahook'
  },
  {
    'pass' => 1,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'datahook'
  },
  {
    'pass' => 1,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'datahook'
  },
  {
    'pass' => 1,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'endrepeathook'
  },
  {
    'pass' => 0,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'beginrepeathook'
  },
  {
    'pass' => 0,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'datahook'
  },
  {
    'pass' => 0,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'datahook'
  },
  {
    'pass' => 0,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'datahook'
  },
  {
    'pass' => 0,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'datahook'
  },
  {
    'pass' => 0,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'datahook'
  },
  {
    'pass' => 0,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'endrepeathook'
  },
  {
    'pass' => 1,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'beginrepeathook'
  },
  {
    'pass' => 1,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'datahook'
  },
  {
    'pass' => 1,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'datahook'
  },
  {
    'pass' => 1,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'datahook'
  },
  {
    'pass' => 1,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'datahook'
  },
  {
    'pass' => 1,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'datahook'
  },
  {
    'pass' => 1,
    'probability' => 1,
    'datacap' => 5,
    'hook' => 'endrepeathook'
  }
]

@@ end_vars
[
  {
    'subtotals' => '4:4',
    'max' => '4',
    'total' => '8',
    'hook' => 'endrepeathook'
  },
  {
    'subtotals' => '4:4',
    'max' => '4',
    'total' => '8',
    'hook' => 'endrepeathook'
  },
  {
    'subtotals' => '4:4',
    'max' => '4',
    'total' => '8',
    'hook' => 'endtesthook'
  },
  {
    'subtotals' => '4:9',
    'max' => '9',
    'total' => '13',
    'hook' => 'endrepeathook'
  },
  {
    'subtotals' => '4:9',
    'max' => '9',
    'total' => '13',
    'hook' => 'endrepeathook'
  },
  {
    'subtotals' => '4:9',
    'max' => '9',
    'total' => '13',
    'hook' => 'endtesthook'
  },
  {
    'subtotals' => '4:9',
    'max' => '9',
    'total' => '13',
    'hook' => 'endhook'
  }
]

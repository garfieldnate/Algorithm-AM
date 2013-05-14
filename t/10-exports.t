#test exported variables and methods
use strict;
use warnings;
use feature qw(say state);
use Test::More 0.88;
plan tests => 5*34 + 1;
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
);

my $project_path = path($Bin, 'data', 'chapter3_multi_test');

my $am = Algorithm::AM->new(
	$project_path,
	-commas => 'no',
	-repeat => 2,
);
my @record;
$am->classify(
	-beginhook => \&beginhook,
	-begintesthook => \&begintesthook,
	-beginrepeathook => \&beginrepeathook,
	-datahook => \&datahook,
	-endrepeathook => \&endrepeathook,
	-endtesthook => \&endtesthook,
	-endhook => \&endhook,
);

my $current_data = eval get_data_section('current_item');
is_deeply(log_current_item(), $current_data, 'current item maintained correctly')
	or note explain log_current_item();

# print Dumper log_current_item();
sub beginhook {
	# say 'beginhook';
	test_beginning_vars();
}

sub begintesthook {
	# say 'begintesthook';
	test_beginning_vars();
	log_current_item('begintesthook');
}

sub beginrepeathook {
	# say 'beginrepeathook';
	test_beginning_vars();
	log_current_item('beginrepeathook');
}

sub datahook {
	# say 'datahook';
	test_beginning_vars();
	log_current_item('datahook');
}
sub endrepeathook {
	# say 'endrepeathook';
	test_beginning_vars();
	log_current_item('endrepeathook');
}

sub endtesthook {
	# say 'endtesthook';
	test_beginning_vars();
	log_current_item('endtesthook');
}

sub endhook {
	# say 'endhook';
	test_beginning_vars();
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

sub log_current_item {
	state @log;
	my ($hook) = @_;
	return \@log
		unless $hook;
    # warn join ':', @curTestItem;
	push @log, {
		hook => $hook,
		outcome =>	$curTestOutcome,
		data => join(':', @curTestItem),
		spec => $curTestSpec,
	};

	return \@log;
}

__DATA__
@@ current_item
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
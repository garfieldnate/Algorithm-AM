# test hooks
use strict;
use warnings;
use Algorithm::AM;
use Test::More 0.88;
plan tests => 3;
use Test::NoWarnings;
use t::TestAM 'chapter_3_project';

my $project = chapter_3_project();
$project->add_test([qw(3 1 2)], 'second test item', 'e');

my $am = Algorithm::AM->new(
	$project,
	commas => 'no',
	repeat => 2,
);

#first test that each hook is called at the appropriate time
#by recording the call of each hook in @record
my @record;
my @args;
push @args, ("$_", record_hook($_))
	for qw(
		beginhook
		begintesthook
		beginrepeathook
		datahook
		endrepeathook
		endtesthook
		endhook
	);

sub record_hook {
	my ($hook_name) = @_;
	return sub {
		push @record, $hook_name;
	};
}

$am->classify(@args);
my @expected = (
	q(beginhook),
	(
		qw(
			begintesthook
			beginrepeathook
		),
		qw(datahook) x 5,
		qw(
			endrepeathook
			beginrepeathook
		),
		qw(datahook) x 5,
		qw(
			endrepeathook
			endtesthook
		)
	) x 2,
	q(endhook)
);
is_deeply(\@record, \@expected, 'hooks called in expected order')
	or note explain \@record;

#now check that the return value of datahook is correctly interpreted
my ($result) = $am->classify(
	datahook 	=> sub {
		my ($am, $data, $index) = @_;
		#will be false for index 0, so index 0 will be removed
		return $index;
	},
	repeat => 1,
);

# check that 1 item was excluded, and the item we meant to exclude
# does not appear in the analogical set (as it would if it were included)
# TODO: add a real API for querying included data...
is_deeply($result->excluded_data, [0],
	'item one excluded via datahook')
	or note explain $result->excluded_data;

# clean up amcpresults file
unlink $project->results_path
	if -e $project->results_path;

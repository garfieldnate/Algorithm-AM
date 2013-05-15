#test hooks
use strict;
use warnings;
use Test::More 0.88;
plan tests => 3;
use Test::LongString;
use Algorithm::AM;
use FindBin qw($Bin);
use Path::Tiny;
use File::Slurp;

my $project_path = path($Bin, 'data', 'chapter3_multi_test');
my $results_path = path($project_path, 'amcpresults');

my $am = Algorithm::AM->new(
	$project_path,
	-commas => 'no',
	-repeat => 2,
);

#first test that each hook is called at the appropriate time
#by recording the call of each hook in @record
my @record;
my @args;
push @args, ("-$_", record_hook($_))
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

#clean up previous test runs
unlink $results_path
	if -e $results_path;

#now check that the return value of datahook is correctly interpreted
$am->classify(
	-datahook 	=> sub {
		my ($index) = @_;
		#will be false for index 0, so index 0 will be removed
		return $index;
	},
	-repeat => 1,
	-gangs => 'yes',
);

my $results = read_file($results_path);
like_string($results, qr/Total Excluded:\s+1/, 'False datahook return excludes item');
unlike_string($results, qr/3 1 0/, 'item specified by datahook is not present in output');

# clean up amcpresults file
unlink $results_path
	if -e $results_path;

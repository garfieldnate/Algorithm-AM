#test hooks
use feature 'say';
use Test::More 0.88;
plan tests => 1;
use Algorithm::AM;
use FindBin qw($Bin);
use Path::Tiny;

my $project_path = path($Bin, 'data', 'chapter3');

my $am = Algorithm::AM->new(
	$project_path,
	-commas => 'no',
	-repeat => 2,
);
my @record;
$am->classify(
	-beginhook => \&beginhook,
	-endhook => \&endhook,
	-begintesthook => \&begintesthook,
	-endtesthook => \&endtesthook,
	-endrepeathook => \&endrepeathook,
	-beginrepeathook => \&beginrepeathook,
	-datahook => \&datahook,
);
my @expected = qw(
	beginhook
	begintesthook
	beginrepeathook
	datahook
	datahook
	datahook
	datahook
	datahook
	endrepeathook
	beginrepeathook
	datahook
	datahook
	datahook
	datahook
	datahook
	endrepeathook
	endtesthook
	endhook
);
is_deeply(\@record, \@expected)
	or note explain \@record;

sub beginhook {
	push @record, 'beginhook';
}

sub endhook {
	push @record, 'endhook';
}

sub begintesthook {
	push @record, 'begintesthook';
}

sub endtesthook {
	push @record, 'endtesthook';
}

sub endrepeathook {
	push @record, 'endrepeathook';
}

sub beginrepeathook {
	push @record, 'beginrepeathook';
}

sub datahook {
	push @record, 'datahook';
}
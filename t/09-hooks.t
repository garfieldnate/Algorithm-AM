#test hooks
use strict;
use warnings;
use Test::More 0.88;
plan tests => 1;
use Algorithm::AM;
use FindBin qw($Bin);
use Path::Tiny;

my $project_path = path($Bin, 'data', 'chapter3_multi_test');

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
is_deeply(\@record, \@expected, 'hooks called in expected order')
	or note explain \@record;

sub beginhook {
	push @record, 'beginhook';
}

sub begintesthook {
	push @record, 'begintesthook';
}

sub beginrepeathook {
	push @record, 'beginrepeathook';
}

sub datahook {
	push @record, 'datahook';
}

sub endrepeathook {
	push @record, 'endrepeathook';
}

sub endtesthook {
	push @record, 'endtesthook';
}

sub endhook {
	push @record, 'endhook';
}

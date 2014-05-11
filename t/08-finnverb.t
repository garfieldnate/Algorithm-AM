# test the finnverb data set and check how many items
# were correctly classified. With default settings,
# it should get 161 correct out of 173.
use strict;
use warnings;
use Algorithm::AM;
use Algorithm::AM::Batch;
use Test::More 0.88;
plan tests => 2;
use Test::NoWarnings;

use FindBin qw($Bin);
use Path::Tiny;

my $train = dataset_from_file(
    path => path($Bin, 'data', 'finnverb', 'data'),
    format => 'nocommas',
    unknown => '='
);
my $am = Algorithm::AM::Batch->new(
    training_set => $train,
    test_set => $train,
    exclude_given => 1,
);

my $count = 0;
$am->classify(
    endtesthook   => sub {
        my ($am, $test_item, $data, $result) = @_;
        ++$count if $result->result ne 'incorrect';
    }
);

is($count, 161, '161 out of 173 items correctly predicted');

# test repeat classification option
use strict;
use warnings;
use Algorithm::AM;
use Test::More 0.88;
plan tests => 2;
use Test::NoWarnings;
use t::TestAM qw(chapter_3_train chapter_3_test);

my $train = chapter_3_train();
my $test = chapter_3_test();

my $am = Algorithm::AM->new(
    train => $train,
    test => $test,
    repeat => 2
);
my @results = $am->classify();
is(scalar @results, 2, 'exemplar is analyzed twice') or
    note scalar @results;

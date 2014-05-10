#test setting exemplar inclusion probability
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
my ($result) = $am->classify(probability => .9);
#TODO: test this more explicitly, perhaps by overriding rand()
is($result->probability, .9, 'probability recorded in result')
    or note $result->probability;

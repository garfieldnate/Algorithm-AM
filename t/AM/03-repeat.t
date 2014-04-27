# test repeat classification option
use strict;
use warnings;
use Algorithm::AM;
use Test::More 0.88;
plan tests => 2;
use Test::NoWarnings;
use t::TestAM 'chapter_3_project';

my $project = chapter_3_project();

my $am = Algorithm::AM->new($project, repeat => 2);
my @results = $am->classify();
is(scalar @results, 2, 'exemplar is analyzed twice') or
    note scalar @results;

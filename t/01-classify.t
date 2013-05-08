#basic test file

use strict;
use warnings;
use Algorithm::AM;
use FindBin qw($Bin);
use Test::More;

plan tests => 1;
my $am = Algorithm::AM->new("$Bin/data/finnverb", -commas => 'no', -given => 'exclude');

ok(1);
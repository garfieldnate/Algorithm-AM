# The example data set that always came with AM. Just run
# to see output and make sure it doesn't die.

use Algorithm::AM;
# use strict; # not yet...
use warnings;
use FindBin qw($Bin);
use Path::Tiny;
use Test::More tests => 2;
use Test::NoWarnings;

my $p = Algorithm::AM->new(
    path($Bin, 'data', 'finnverb'),
    -commas => 'no',
    -given => 'exclude'
);

my $count    = 0;
my @confusion;
my $countsub = sub {
    my ($am, $data) = @_;
    my $sum = $data->{sum};
    my $pointermax = $data->{pointermax};
    my $curTestOutcome = ${$data->{curTestOutcome}};

    ++$count if $sum->[$curTestOutcome] eq $pointermax;
};

my $begin = sub {
    @confusion = ();
};
my $endrepeat = sub {
    my ($am, $data) = @_;
    my $sum = $data->{sum};
    my $curTestOutcome = ${$data->{curTestOutcome}};
    my $pointermax = $data->{pointermax};
    my $outcomelist = $data->{outcomelist};

    if ( !$data->{pointertotal} ) {
        ++$confusion[$curTestOutcome][0];
        return;
    }
    if ( $sum->[$curTestOutcome] eq $pointermax ) {
        ++$confusion[$curTestOutcome][$curTestOutcome];
        return;
    }
    my @winners = ();
    for my $i ( 1 .. $#$outcomelist ) {
        push @winners, $i if $sum->[$i] == $pointermax;
    }
    my $numwinners = scalar @winners;
    foreach (@winners) {
        $confusion[$curTestOutcome][$_] += 1 / $numwinners;
    }
};

my $end = sub {
    my ($am, $data) = @_;
    my $outcomelist = $data->{outcomelist};

    for my $i ( 1 .. $#$outcomelist ) {
        my $total = 0;
        foreach ( @{ $confusion[$i] } ) {
            $total += $i;
        }
        next unless $total;
        printf "Test items with outcome $am->{oformat} were predicted as follows:\n",
          $outcomelist->[$i];
        for my $j ( 1 .. $#$outcomelist ) {
            next unless ( my $t = $confusion[$i][$j] );
            printf "%7.3f%% $am->{oformat}  (%i/%i)\n", 100 * $t / $total,
              $outcomelist->[$j], $t, $total;
        }
        if ( my $t = $confusion[$i][0] ) {
            printf "%7.3f%% could not be predicted (%i/%i)\n",
              100 * $t / $total, $t, $total;
        }
        print "\n\n";
    }
    print "Number of correct predictions: $count\n";
};

$p->classify(
    -beginhook     => $begin,
    -endtesthook   => $countsub,
    -endrepeathook => $endrepeat,
    -endhook       => $end
);

ok(1);
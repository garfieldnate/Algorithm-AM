use Algorithm::AM;
# use strict; #not yet...
use warnings;
use FindBin qw($Bin);
use Path::Tiny;
use Test::More tests => 1;

my $p = Algorithm::AM->new( path($Bin, 'data', 'finnverb'), -commas => 'no', -given => 'exclude' );

my $count    = 0;
my $countsub = sub {
    ++$count if $sum[$curTestOutcome] eq $pointermax;
};

my $begin = sub {
    @confusion = ();
};
my $endrepeat = sub {
    if ( !$pointertotal ) {
        ++$confusion[$curTestOutcome][0];
        return;
    }
    if ( $sum[$curTestOutcome] eq $pointermax ) {
        ++$confusion[$curTestOutcome][$curTestOutcome];
        return;
    }
    my @winners = ();
    for my $i ( 1 .. $#outcomelist ) {
        push @winners, $i if $sum[$i] == $pointermax;
    }
    my $numwinners = scalar @winners;
    foreach (@winners) {
        $confusion[$curTestOutcome][$_] += 1 / $numwinners;
    }
};
$end = sub {
    for my $i ( 1 .. $#outcomelist ) {
        my $total = 0;
        foreach ( @{ $confusion[$i] } ) {
            $total += $i;
        }
        next unless $total;
        printf "Test items with outcome $oformat were predicted as follows:\n",
          $outcomelist[$i];
        for my $j ( 1 .. $#outcomelist ) {
            my $t;
            next unless ( $t = $confusion[$i][$j] );
            printf "%7.3f%% $oformat  (%i/%i)\n", 100 * $t / $total,
              $outcomelist[$j], $t, $total;
        }
        if ( $t = $confusion[$i][0] ) {
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
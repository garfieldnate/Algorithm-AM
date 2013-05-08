use Algorithm::AM;

$p = Algorithm::AM->new('finnverb', -commas => 'no', -given => 'exclude');

$count = 0;
$countsub = sub {
    ++$count if $sum[$curTestOutcome] eq $pointermax;
};

  $begin = sub {
    @confusion = ();
  };
  $endrepeat = sub {
    if (!$pointertotal) {
      ++$confusion[$curTestOutcome][0];
      return;
    }
    if ($sum[$curTestOutcome] eq $pointermax) {
      ++$confusion[$curTestOutcome][$curTestOutcome];
      return;
    }
    my @winners = ();
    my $i;
    for ($i = 1; $i < @outcomelist; ++$i) {
      push @winners, $i if $sum[$i] == $pointermax;
    }
    my $numwinners = scalar @winners;
    foreach (@winners) {
      $confusion[$curTestOutcome][$_] += 1 / $numwinners;
    }
  };
  $end = sub {
    my($i,$j);
    for ($i = 1; $i < @outcomelist; ++$i) {
      my $total = 0;
      foreach (@{$confusion[$i]}) {
        $total += $_;
      }
      next unless $total;
      printf "Test items with outcome $oformat were predicted as follows:\n",
        $outcomelist[$i];
      for ($j = 1; $j < @outcomelist; ++$j) {
        my $t;
        next unless ($t = $confusion[$i][$j]);
        printf "%7.3f%% $oformat  (%i/%i)\n", 100 * $t / $total, $outcomelist[$j], $t, $total;
      }
      if ($t = $confusion[$i][0]) {
        printf "%7.3f%% could not be predicted (%i/%i)\n", 100 * $t / $total, $t, $total;
      }
      print "\n\n";
    }
    print "Number of correct predictions: $count\n";
  };


$p->(-beginhook => $begin, -endtesthook => $countsub,
     -endrepeathook => $endrepeat, -endhook => $end);



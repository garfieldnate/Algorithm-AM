# encapsulate information about a single classification result
package Algorithm::AM::Result;
use strict;
use warnings;
# ABSTRACT: Store results of an AM classification
# VERSION;
use Class::Tiny qw(
    exclude_nulls
    excluded_data
    given_excluded
    exclude_given
    num_variables
    test_in_data
    test_item
    test_spec
    test_outcome
    probability
    count_method
    datacap

    start_time
    end_time

    project
    high_score
    winners
    is_tie
    result

    gang_format

    scores
);
use Algorithm::AM::BigInt 'bigcmp';

=head2 C<config_info>

Returns a scalar (string) ref containing information about the
configuration at the time of classification. Information from the
following accessors is included:

    exclude_nulls
    excluded_data
    given_excluded
    exclude_given
    num_variables
    test_in_data
    test_item
    test_spec
    probability
    count_method
    datacap

=cut
sub config_info {
    my ($self) = @_;
    my $info = '';
    $info .=
        "Given Context:  @{ $self->{test_item} }, $self->{test_spec}\n";
    if($self->{exclude_given}){
        $info .= "If context is in data file then exclude\n";
    }else{
        $info .= "Include context even if it is in the data file\n";
    }
    $info .= "Number of data items: $self->{datacap}\n";
    if (defined $self->{probability}){
        $info .= 'Probability of including any one data item: ' .
            $self->{probability} . "\n";
    }
    $info .= "Total Excluded: $self->{excluded_data} " .
        ($self->{given_excluded} ? " + test item\n" : "\n");
    $info .= 'Nulls: ' . ($self->{exclude_nulls} ? 'exclude' : 'include')
        . "\n";
    $info .= "Gang: $self->{count_method}\n";
    $info .= "Number of active variables: $self->{num_variables}\n";
    if($self->{test_in_data}){
        $info .= "Test item is in the data.\n";
    }
    return \$info;
}

# given the grandtotal, create a format for printing gangs
# then return the current grandtotal
sub grandtotal {
    my ($self, $grandtotal) = @_;
    if($grandtotal){
        my $length = length $grandtotal;
        $self->{gang_format} = "%$length.${length}s";
        $self->{grandtotal} = $grandtotal;
    }
    return $self->{grandtotal};
}

=head2 C<statistical_summary>

Returns a scalar reference (string) containing a statistical summary
of the classification results. The summary includes all possible
predicted outcomes with their numbers of pointers and percentage
scores and the total number of pointers. Whether the predicted outcome
is correct/incorrect/a tie of some sort is also printed, if the
expected outcome has been provided.

=cut
sub statistical_summary {
    my ($self) = @_;
    my %scores = %{$self->scores};
    my $outcome_format = $self->project->outcome_format;
    my $grand_total = $self->grandtotal;
    my $gang_format = $self->{gang_format};

    my $info = "Statistical Summary\n";
    for my $outcome(sort keys %scores){
        $info .=
            # outcome name, number of pointers,
            # and percentage predicted
            sprintf(
                "$outcome_format  $gang_format  %7.3f%%\n",
                $outcome,
                $scores{$outcome},
                100 * $scores{$outcome} / $grand_total
            );
    }
    # separator row of dashes (-) followed by the grandtotal in
    # the same column as the other pointer numbers were printed
    $info .= sprintf(
        "$outcome_format  $gang_format\n",
        "", '-' x length $grand_total );
    $info .= sprintf(
        "$outcome_format  $gang_format\n",
        "", $grand_total );
    # the predicted outcome (the one with the highest number
    # of pointers) and whether or not the prediction was correct.
    # TODO: should note if there's a tie
    if ( defined (my $outcome = $self->test_outcome) ) {
        $info .= "Expected outcome: $outcome\n";
        if ( $self->result() =~ /^tie$|^correct$/) {
            $info .= "Correct outcome predicted.\n";
        }
        else {
            $info .= "Incorrect outcome predicted\n";
        }
    }
    return \$info;
}

sub analogical_set_summary {
    my ($self) = @_;
    my $project = $self->project;
    my $grandtotal = $self->grandtotal;
    my $outcome_format = $project->outcome_format;
    my $spec_format = $project->spec_format;
    my $gang_format = $self->{gang_format};

    my $info = "Analogical Set\nTotal Frequency = $grandtotal\n";
    # print each item that contributed pointers to the
    # outcome, grouping items by common subcontexts.
    foreach my $context ( keys %{$self->{pointers}} ) {
        next unless
            exists $self->{itemcontextchainhead}->{$context};
        for (
            my $data_index = $self->{itemcontextchainhead}->{$context};
            defined $data_index;
            $data_index = $self->{itemcontextchain}->[$data_index]
        )
        {
            my $score = $self->{pointers}->{$context};
            $info .=
                sprintf(
                    "$outcome_format  $spec_format  $gang_format  %7.3f%%",
                    $project->get_outcome(
                        $project->get_exemplar_outcome($data_index) ),
                    $project->get_exemplar_spec($data_index),
                    $score, 100 * $score / $grandtotal
                ) . "\n";
        }
        # write a separator line between contexts
        $info .= "-----\n";
    }
    return \$info;
}

# $print_list means print everything, not just the summary
sub gang_summary {
    my ($self, $print_list) = @_;
    my $project = $self->project;
    my $gang_format = $self->{gang_format};
    my $outcome_format = $project->outcome_format;
    my $data_format = $project->data_format;
    my $grandtotal = $self->grandtotal;
    my $var_format = $project->var_format;
    my $test_item = $self->test_item;

    my $info = "Gang effects\n";
    #TODO: explain the magic below
    my $dashes = '-' x ( (length $self->grandtotal)  + 10 );
    my $pad = " " x length sprintf "%7.3f%%  $gang_format x $data_format  $outcome_format",
      0, '0', 0, "";
    foreach my $context (
        sort { bigcmp($self->{gang}->{$b}, $self->{gang}->{$a})}
            keys %{$self->{gang}}
    )
    {
        # start by unpacking the (supra)contexts for printing
        my @context_list   = unpack "S!4", $context;
        my @alist   = @{$self->{active_vars}};
        my (@vtemp) = @{ $test_item };
        my $j       = 1;
        while (@alist) {
            my $a = pop @alist;
            my $partial_context = pop @context_list;
            for ( ; $a ; --$a ) {
                if($self->{exclude_nulls}){
                    ++$j while $vtemp[ -$j ] eq '=';
                }
                $vtemp[ -$j ] = '' if $partial_context & 1;
                $partial_context >>= 1;
                ++$j;
            }
        }
        my $p = $self->{pointers}->{$context};
        if ( $self->{subtooutcome}->{$context} ) {
            {
                no warnings;
                # print the effect of the gang
                $info .= sprintf(
                    "%7.3f%%  $gang_format   $data_format  $outcome_format  $var_format",
                    100 * $self->{gang}->{$context} / $grandtotal,
                    $self->{gang}->{$context}, "", "", @{ $test_item }
                ) . "\n";
                # print dashes and the name of the supracontext
                $info .= sprintf(
                    "$dashes   $data_format  $outcome_format  $var_format",
                    "", "", @vtemp
                ) . "\n";
            }
            $info .= sprintf(
                "%7.3f%%  $gang_format x $data_format  $outcome_format",
                100 * $self->{gang}->{$context} / $grandtotal,
                $p,
                $self->{contextsize}->{$context},
                $project->get_outcome($self->{subtooutcome}->{$context} )
            ) . "\n";
            if($print_list){
                my $i;
                for (
                    $i = $self->{itemcontextchainhead}->{$context} ;
                    defined $i ;
                    $i = $self->{itemcontextchain}->[$i]
                  )
                {
                    $info .= sprintf(
                        "$pad  $var_format  " .
                        $project->get_exemplar_spec($i),
                        @{ $project->get_exemplar_data($i) } ) . "\n";
                }
            }
        }
        else {
            my @gangsort = (0) x ($project->num_outcomes + 1);
            my @ganglist = ();
            my $i;
            for (
                $i = $self->{itemcontextchainhead}->{$context} ;
                defined $i ;
                $i = $self->{itemcontextchain}->[$i]
              )
            {
                ++$gangsort[ $project->get_exemplar_outcome($i) ];
                if($print_list){
                    push @{ $ganglist[
                        $project->get_exemplar_outcome($i) ] }, $i;
                }
            }
            {
                no warnings;
                $info .= sprintf(
"%7.3f%%  $gang_format   $data_format  $outcome_format  $var_format",
                    100 * $self->{gang}->{$context} / $grandtotal,
                    $self->{gang}->{$context}, "", "", @{ $test_item }
                ) . "\n";
                $info .= sprintf (
                    "$dashes   $data_format  $outcome_format  $var_format",
                    "", "", @vtemp) . "\n";
            }
            for $i ( 1 .. $project->num_outcomes ) {
                next unless $gangsort[$i];
                $info .= sprintf(
                    "%7.3f%%  $gang_format x $data_format  $outcome_format",
                    100 * $gangsort[$i] * $p / $grandtotal,
                    $p, $gangsort[$i], $project->get_outcome($i)
                ) . "\n";
                if($print_list){
                    foreach ( @{ $ganglist[$i] } ) {
                        $info .= sprintf( "$pad  $var_format  " .
                            $project->get_exemplar_spec($_),
                            @{ $project->get_exemplar_data($_) }
                        ) . "\n";
                    }
                }
            }
        }
    }
    return \$info;
}

# input several variables from AM's guts (grandtotal, sum,
# expected outcome integer, pointers, itemcontextchainhead and
# itemcontextchain). Calculate the prediction statistics, and
# store information needed for computing analogical sets.
# Set result to tie/correct/incorrect if expected outcome is
# provided, and set is_tie, high_score, scores, winners, and
# grandtotal.
sub _process_stats {
    my ($self, $grandtotal, $sum, $expected, $pointers,
        $itemcontextchainhead, $itemcontextchain, $subtooutcome,
        $gang, $active_vars, $contextsize) = @_;
    my $max = '';
    my @winners;
    my %scores;

    # iterate all possible outcomes and store the ones that have a
    # non-zero score. Store the high-scorers, as well.
    # 1) find which one(s) has the most pointers (is the prediction) and
    # 2) print out the ones with pointers (change of prediction)
    for my $outcome_index (1 .. $self->project->num_outcomes) {
        my $outcome_pointers;
        # skip outcomes with no pointers
        next unless $outcome_pointers = $sum->[$outcome_index];

        my $outcome = $self->project->get_outcome($outcome_index);
        $scores{$outcome} = $outcome_pointers;

        # check if the outcome has the highest score, or ties for it
        do {
            my $cmp = bigcmp($outcome_pointers, $max);
            if ($cmp > 0){
                @winners = ($outcome);
                $max = $outcome_pointers;
            }elsif($cmp == 0){
                push @winners, $outcome;
            }
        };
    }

    # set result to tie/correct/incorrect after comparing
    # expected/actual outcomes
    if($expected){
        #set the expected outcome to the string representation
        my $test_outcome = $self->project->get_outcome($expected);
        $self->test_outcome($test_outcome);
        if(exists $scores{$test_outcome} &&
                bigcmp($scores{$test_outcome}, $max) == 0){
            if(@winners > 1){
                $self->result('tie');
            }else{
                $self->result('correct');
            }
        }else{
            $self->result('incorrect');
        }
    }
    if(@winners > 1){
        $self->is_tie(1);
    }
    $self->high_score($max);
    $self->scores(\%scores);
    $self->winners(\@winners);
    $self->grandtotal($grandtotal);
    $self->{pointers} = $pointers;
    $self->{itemcontextchainhead} = $itemcontextchainhead;
    $self->{itemcontextchain} = $itemcontextchain;
    $self->{subtooutcome} = $subtooutcome;
    $self->{gang} = $gang;
    $self->{active_vars} = $active_vars;
    $self->{contextsize} = $contextsize;
    return;
}

1;

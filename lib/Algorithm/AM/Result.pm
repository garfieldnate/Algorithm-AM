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
        $self->gang_format("%$length.${length}s");
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
    my $gang_format = $self->gang_format;

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
    my $gang_format = $self->gang_format;

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

# input several variables from AM's guts (grandtotal, sum,
# expected outcome integer, pointers, itemcontextchainhead and
# itemcontextchain). Calculate the prediction statistics, and
# store information needed for computing analogical sets.
# Set result to tie/correct/incorrect if expected outcome is
# provided, and set is_tie, high_score, scores, winners, and
# grandtotal.
sub _process_stats {
    my ($self, $grandtotal, $sum, $expected, $pointers,
        $itemcontextchainhead, $itemcontextchain) = @_;
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
    return;
}

1;

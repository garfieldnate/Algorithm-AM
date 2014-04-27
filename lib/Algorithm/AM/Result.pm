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
    $info .= 'Total Excluded: ' . scalar @{$self->excluded_data} .
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

# given the total number of pointers, create a format for printing gangs
# then return the current total number of pointers
sub total_pointers {
    my ($self, $total_pointers) = @_;
    if($total_pointers){
        my $length = length $total_pointers;
        $self->{gang_format} = "%$length.${length}s";
        $self->{total_pointers} = $total_pointers;
    }
    return $self->{total_pointers};
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
    my $grand_total = $self->total_pointers;
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
    # separator row of dashes (-) followed by the total_pointers in
    # the same column as the other pointer numbers were printed
    $info .= sprintf(
        "$outcome_format  $gang_format\n",
        '', '-' x length $grand_total );
    $info .= sprintf(
        "$outcome_format  $gang_format\n",
        '', $grand_total );
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

=head2 C<analogical_set>

Returns the analogical set in the form of a hash ref mapping exemplar
indices to the number of pointers contributed by the item towards
the final classification outcome. Further information about each
exemplar can be retrieved from the project object using
C<get_exemplar_(data|spec|outcome)> methods.

=cut
sub analogical_set {
    my ($self) = @_;
    if(!exists $self->{_analogical_set}){
        $self->_calculate_analogical_set;
    }
    # make a safe copy
    my %set = %{$self->{_analogical_set}};
    return \%set;
}

=head2 C<analogical_set_summary>

Returns a scalar reference (string) containing the analogical set,
meaning all items that contributed to the predicted outcome, along
with the amount contributed by each item (number of pointers and
percentage overall). Items are ordered by appearance in the data
set.

=cut
sub analogical_set_summary {
    my ($self) = @_;
    if(!exists $self->{_analogical_set}){
        $self->_calculate_analogical_set;
    }
    my $set = $self->{_analogical_set};
    my $project = $self->project;
    my $total_pointers = $self->total_pointers;
    my $outcome_format = $project->outcome_format;
    my $spec_format = $project->spec_format;
    my $gang_format = $self->{gang_format};

    my $info = "Analogical Set\nTotal Frequency = $total_pointers\n";
    # print each item that contributed pointers to the
    # outcome, ordered by appearance in the dataset
    foreach my $data_index (sort keys %$set){
        my $score = $set->{$data_index};
        $info .=
            sprintf(
                "$outcome_format  $spec_format  $gang_format  %7.3f%%",
                $project->get_outcome(
                    $project->get_exemplar_outcome($data_index) ),
                $project->get_exemplar_spec($data_index),
                $score, 100 * $score / $total_pointers
            ) . "\n";
    }
    return \$info;
}

# calculate and store analogical effects in $self->{_analogical_set}
sub _calculate_analogical_set {
    my ($self) = @_;
    my %set;
    foreach my $context ( keys %{$self->{pointers}} ) {
        next unless
            exists $self->{itemcontextchainhead}->{$context};
        for (
            my $data_index = $self->{itemcontextchainhead}->{$context};
            defined $data_index;
            $data_index = $self->{itemcontextchain}->[$data_index]
        )
        {
            $set{$data_index} = $self->{pointers}->{$context};
        }
    }
    $self->{_analogical_set} = \%set;
    return;
}

=head2 C<gang_effects>

Return a hash describing gang effects.
TODO: details, details!

=cut
sub gang_effects {
    my ($self) = @_;
    if(!$self->{_gang_effects}){
        $self->_calculate_gangs;
    }
    return $self->{_gang_effects};
}

=head2 C<gang_summary>

Returns a scalar reference (string) containing the gang effects on the
final outcome. Gang effects are basically the same as analogical sets,
but the total effects of entire subcontexts and supracontexts
are also calculated and printed.

A single boolean parameter can be provided to turn on full list
printing, meaning that all relevant items are printed. This is false
(off) by default.

=cut
# $print_list means print everything, not just the summary
sub gang_summary {
    my ($self, $print_list) = @_;
    my $project = $self->project;
    my $gang_format = $self->{gang_format};
    my $outcome_format = $project->outcome_format;
    my $data_format = $project->data_format;
    my $total_pointers = $self->total_pointers;
    my $var_format = $project->var_format;
    my $test_item = $self->test_item;
    my $gang = $self->{gang};

    #TODO: explain the magic below
    my $dashes = '-' x ( (length $self->total_pointers)  + 10 );
    my $row_length =
        length sprintf(
        "%7.3f%%  $gang_format x $data_format  $outcome_format",
        0, '0', 0, '');
    my $pad = ' ' x $row_length;
    my $header = 'Gang effects';

    #first print a header with test item for easy reference
    my $info = sprintf(
        "Gang effects $gang_format $data_format $outcome_format  $var_format\n",
        '', '0', '', @$test_item
    );

    foreach my $context (
        sort { bigcmp($gang->{$b}, $gang->{$a})}
            keys %{$gang}
    )
    {
        my @variables = $self->_unpack_supracontext($context);
        my $score = $self->{pointers}->{$context};
        # if the supracontext is heterogeneous
        if ( $self->{subtooutcome}->{$context} ) {
            # print the supracontext and its effect and number of pointers
            $info .= sprintf(
                "%7.3f%%  $gang_format   $data_format  $outcome_format  $var_format\n",
                100 * $gang->{$context} / $total_pointers,
                $gang->{$context}, '0', '', @variables
            );
            # print dashes to accent the supracontext header
            $info .= "$dashes\n";
            # we know that the supracontext in homogeneous and so there
            # is only one supported outcome. Print the effect of the gang,
            # the number of items in the gang, and the supported outcome.
            $info .= sprintf(
                "%7.3f%%  $gang_format x $data_format  $outcome_format",
                100 * $gang->{$context} / $total_pointers,
                $score,
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
                    # print the list of items in the given context
                    # (they all have the given outcome)
                    $info .= sprintf(
                        "$pad  $var_format  " .
                        $project->get_exemplar_spec($i) . "\n",
                        @{ $project->get_exemplar_data($i) } );
                }
            }
        }
        else {
            # else if the supracontext is heterogeneous
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
            # print supracontext name and effect
            $info .= sprintf(
"%7.3f%%  $gang_format   $data_format  $outcome_format  $var_format\n",
                100 * $gang->{$context} / $total_pointers,
                $gang->{$context}, '0', '', @variables
            );
            # print dashes to accent the header
            $info .= "$dashes\n";
            for $i ( 1 .. $project->num_outcomes ) {
                next unless $gangsort[$i];
                $info .= sprintf(
                    "%7.3f%%  $gang_format x $data_format  $outcome_format\n",
                    100 * $gangsort[$i] * $score / $total_pointers,
                    $score, $gangsort[$i], $project->get_outcome($i)
                );
                # print the list of items in the given context and outcome
                if($print_list){
                    foreach ( @{ $ganglist[$i] } ) {
                        $info .= sprintf( "$pad  $var_format  " .
                            $project->get_exemplar_spec($_) . "\n",
                            @{ $project->get_exemplar_data($_) }
                        );
                    }
                }
            }
        }
    }
    return \$info;
}

# Unpack and return the supracontext variables.
# Blank entries mean the variable may be anything, e.g.
# ('a' 'b' '') means a supracontext containing items
# wich have ('a' 'b' whatever) as variable values.
sub _unpack_supracontext {
    my ($self, $context) = @_;
    my (@variables) = @{ $self->test_item };
    my @context_list   = unpack "S!4", $context;
    my @alist   = @{$self->{active_vars}};
    my $j       = 1;
    foreach my $a (reverse @alist) {
        my $partial_context = pop @context_list;
        for ( ; $a ; --$a ) {
            if($self->{exclude_nulls}){
                ++$j while $variables[ -$j ] eq '=';
            }
            $variables[ -$j ] = '' if $partial_context & 1;
            $partial_context >>= 1;
            ++$j;
        }
    }
    return @variables;
}

sub _calculate_gangs {
    my ($self) = @_;
    my $test_item = $self->test_item;
    my $project = $self->project;
    my $total_pointers = $self->total_pointers;
    my $raw_gang = $self->{gang};
    my $gangs = {};

    foreach my $context (
        sort { bigcmp($raw_gang->{$b}, $raw_gang->{$a})}
            keys %{$raw_gang}
    )
    {
        my @variables = $self->_unpack_supracontext($context);
        # for now, store gangs by the supracontext printout
        my $key = sprintf($project->var_format, @variables);
        $gangs->{$key}->{score} = $raw_gang->{$context};
        $gangs->{$key}->{effect} = $raw_gang->{$context} / $total_pointers;
        my $p = $self->{pointers}->{$context};
        # if the supracontext is homogenous
        if ( my $outcome = $self->{subtooutcome}->{$context} ) {
            # store a 'homogenous' key that indicates this, besides
            # indicating the unanimous outcome.
            $outcome = $project->get_outcome($outcome);
            $gangs->{$key}->{homogenous} = $outcome;
            $gangs->{$key}->{vars} = \@variables;
            my @data;
            for (
                my $i = $self->{itemcontextchainhead}->{$context};
                defined $i;
                $i = $self->{itemcontextchain}->[$i]
              )
            {
                push @data, $i;
            }
            $gangs->{$key}->{data}->{$outcome} = \@data;
            $gangs->{$key}->{size} = scalar @data;
            $gangs->{$key}->{outcome}->{$outcome}->{score} = $p;
            $gangs->{$key}->{outcome}->{$outcome}->{effect} =
                $gangs->{$key}->{effect};
        }
        # for heterogenous supracontexts we have to store data for
        # each outcome
        else {
            $gangs->{$key}->{homogenous} = 0;
            # first loop through the data and sort by outcome, also
            # finding the total gang size
            my $size = 0;
            my %data;
            for (
                my $i = $self->{itemcontextchainhead}->{$context};
                defined $i;
                $i = $self->{itemcontextchain}->[$i]
              )
            {
                my $outcome = $project->get_outcome(
                    $project->get_exemplar_outcome($i));
                push @{ $data{$outcome} }, $i;
                $size++;
            }
            $gangs->{$key}->{data} = \%data;
            $gangs->{$key}->{size} = $size;

            # then store aggregate statistics for each outcome
            for my $outcome (keys %data){
                $gangs->{$key}->{outcome}->{$outcome}->{score} = $p;
                $gangs->{$key}->{outcome}->{$outcome}->{effect} =
                    # pointers*num_data/total
                    @{ $data{$outcome} } * $p / $total_pointers;
            }
        }
    }
    $self->{_gang_effects} = $gangs;
    return;
}

# input several variables from AM's guts (grandtotal, sum,
# expected outcome integer, pointers, itemcontextchainhead and
# itemcontextchain). Calculate the prediction statistics, and
# store information needed for computing analogical sets.
# Set result to tie/correct/incorrect if expected outcome is
# provided, and set is_tie, high_score, scores, winners, and
# total_pointers.
sub _process_stats {
    my ($self, $total_pointers, $sum, $expected, $pointers,
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
    $self->total_pointers($total_pointers);
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

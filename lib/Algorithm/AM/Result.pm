# encapsulate information about a single classification result
package Algorithm::AM::Result;
use strict;
use warnings;
# ABSTRACT: Store results of an AM classification
# VERSION;

=head2 SYNOPSIS

  use Algorithm::AM;

  my $am = Algorithm::AM->new('finnverb', -commas => 'no');
  my ($result) = $am->classify;
  print @{ $result->winners };
  print $result->statistical_summary;

=head2 DESCRIPTION

This package encapsulates all of the classification information
generated via analogical modeling, including the assigned class,
number of pointers to each class, gang effects, analogical sets,
and timing information. It also provides several methods for
generating printable reports with this information.

=cut
use Class::Tiny qw(
    exclude_nulls
    excluded_data
    given_excluded
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

# input several variables from AM's guts (grandtotal, sum,
# expected outcome integer, pointers, itemcontextchainhead and
# itemcontextchain). Calculate the prediction statistics, and
# store information needed for computing analogical sets.
# Set result to tie/correct/incorrect if expected outcome is
# provided, and set is_tie, high_score, scores, winners, and
# total_pointers.
sub _process_stats {
    my ($self, $total_pointers, $sum, $expected, $pointers,
        $itemcontextchainhead, $itemcontextchain, $context_to_outcome,
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
    $self->{context_to_outcome} = $context_to_outcome;
    $self->{gang} = $gang;
    $self->{active_vars} = $active_vars;
    $self->{contextsize} = $contextsize;
    return;
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
    my $set = $self->analogical_set;
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
TODO: details, details! Maybe make a gang class to hold these.

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

A single boolean parameter can be provided to turn on list printing,
meaning gang items items are printed. This is false (off) by default.

=cut
# $print_list means print everything, not just the summary
sub gang_summary {
    my ($self, $print_list) = @_;
    my $project = $self->project;
    my $gang_format = $self->{gang_format};
    my $outcome_format = $project->outcome_format;
    my $data_format = $project->data_format;
    my $var_format = $project->var_format;
    my $test_item = $self->test_item;

    if(!$self->{_gang_effects}){
        $self->_calculate_gangs;
    }
    my $gangs = $self->gang_effects;

    # TODO: use a module to print pretty columns instead of
    # doing it by hand
    my $dashes = '-' x ( (length $self->total_pointers)  + 10 );
    my $pad = ' ' x length
        sprintf("%7.3f%%  $gang_format x $data_format  $outcome_format",
            0, '0', 0, '');

    #first print a header with test item for easy reference
    my $info = sprintf(
        "Gang effects $gang_format $data_format $outcome_format  $var_format\n",
        '', '0', '', @$test_item
    );

    # print information for each gang; sort by order of highest to
    # lowest effect
    foreach my $gang (
            sort {bigcmp($b->{score}, $a->{score})} values $gangs){
        my $variables = $gang->{vars};
        # print the gang supracontext, effect and number of pointers
        $info .= sprintf(
            "%7.3f%%  $gang_format   $data_format  $outcome_format  $var_format\n",
            100 * $gang->{effect}, $gang->{score}, '0', '', @$variables
        );
        # print dashes to separate the gang header
        $info .= "$dashes\n";
        # print each outcome, along with the total number and effect of
        # the gang items supporting it
        for my $outcome (keys %{ $gang->{outcome} }){
            $info .= sprintf(
                "%7.3f%%  $gang_format x $data_format  $outcome_format",
                100 * $gang->{outcome}->{$outcome}->{effect},
                $gang->{outcome}->{$outcome}->{score},
                scalar @{ $gang->{data}->{$outcome} },
                $outcome
            ) . "\n";
            if($print_list){
                # print the list of items in the given context
                for my $data_index (@{ $gang->{data}->{$outcome} }){
                    $info .= sprintf(
                        "$pad  $var_format  " .
                        $project->get_exemplar_spec($data_index) . "\n",
                        @{ $project->get_exemplar_data($data_index) } );
                }
            }
        }
    }
    return \$info;
}

sub _calculate_gangs {
    my ($self) = @_;
    my $project = $self->project;
    my $total_pointers = $self->total_pointers;
    my $raw_gang = $self->{gang};
    my $gangs = {};

    foreach my $context (keys %{$raw_gang})
    {
        my @variables = $self->_unpack_supracontext($context);
        # for now, store gangs by the supracontext printout
        my $key = sprintf($project->var_format, @variables);
        $gangs->{$key}->{score} = $raw_gang->{$context};
        $gangs->{$key}->{effect} = $raw_gang->{$context} / $total_pointers;
        $gangs->{$key}->{vars} = \@variables;

        my $p = $self->{pointers}->{$context};
        # if the supracontext is homogenous
        if ( my $outcome = $self->{context_to_outcome}->{$context} ) {
            # store a 'homogenous' key that indicates this, besides
            # indicating the unanimous outcome.
            $outcome = $project->get_outcome($outcome);
            $gangs->{$key}->{homogenous} = $outcome;
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

1;

__END__
=head2 Configuration Information

The following methods provide information about the configuration
of AM at the time of classification.

=head2 C<exclude_nulls>

True if null variables were ignored.

=head2 C<excluded_data>

An array ref containing the data indices of any items that were ignored
during classification.

=head2 C<given_excluded>

True if the given item (the test item) was in the data set but was
removed before classification.

=head2 C<num_variables>

The number of variables in the classification data.

=head2 C<test_in_data>

True if the test item was present among the data items.

=head2 C<test_item>

Returns an array ref containing the variables in the test item.

=head2 C<test_spec>

Returns the spec associated with the test item.

=head2 C<test_outcome>

Returns the outcome of the test item.

=head2 C<probability>

Returns the probabibility that any one data item would be included
among the exemplars used during classification, or undef if that was
never set.

=head2 C<count_method>

Returns either "linear" or "squared", indicating the setting used
for counting pointers.

=head2 C<datacap>

Returns the number of data items used to classify the test item.

=head2 C<start_time>

Returns the start time of the classification.

=head2 C<end_time>

Returns the end time of the classification.

=head2 C<project>

Returns the project which was the source of classification data.

=head2 C<high_score>

Returns the highest number of pointers seen among any possible
outcomes.

=head2 C<winners>

Returns an array ref containing the outcomes which had the highest
score. There is more than one only if all of them received the same
score.

=head2 C<is_tie>

Returns true if there is more than one winner, or outcome with the
highest score.

=head2 C<result>

Returns "tie", "correct", or "incorrect", depending on the outcome of
the classification.

=head2 C<gang_format>

Returns a format string that can be used for printing the number of
pointers in a gang.

=head2 C<scores>

Returns a hash mapping all predicted outcomes to their scores, or
the number of pointers associated with them.

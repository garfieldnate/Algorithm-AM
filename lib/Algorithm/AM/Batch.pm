package Algorithm::AM::Batch;
use strict;
use warnings;
# ABSTRACT: Classify items in batch mode
# VERSION
use feature 'state';
use Carp;
our @CARP_NOT = qw(Algorithm::AM::Batch);
use Algorithm::AM;
use Class::Tiny qw(
    training_set

    exclude_nulls
    exclude_given
    linear
    probability
    repeat
    max_training_items

    begin_hook
    begin_repeat_hook
    begin_test_hook
    training_data_hook
    end_test_hook
    end_repeat_hook
    end_hook
), {
    exclude_nulls     => 1,
    exclude_given    => 1,
    linear      => 0,
    probability => 1,
    repeat      => 1,
};

use Log::Any qw($log);

sub BUILD {
    my ($self, $args) = @_;

    if(!exists $args->{training_set}){
        croak "Missing required parameter 'training_set'";
    }
    if(!(ref $args) or !$args->{training_set}->isa(
            'Algorithm::AM::DataSet')){
        croak 'Parameter training_set should be an ' .
            'Algorithm::AM::DataSet';
    }
    for(qw(
        begin_hook
        begin_repeat_hook
        begin_test_hook
        training_data_hook
        end_test_hook
        end_repeat_hook
        end_hook
    )){
        if(exists $args->{$_} and 'CODE' ne ref $args->{$_}){
            croak "Input $_ should be a subroutine";
        }
    }
}

=head2 C<training_set>

Returns the dataset used for training.

=head2 C<test_set>

Returns the dataset used for testing.

=head2 C<classify_all>

Using the analogical modeling algorithm, this method classifies
the test items in the project and returns a list of
L<Result|Algorithm::AM::Result> objects. Information about the current
progress, configuration and timing is logged at the debug level.
The statistical summary, analogical set, and gang summary (without
items listed) are logged at the info level, and the full gang summary
with items listed is logged at the debug level.

=cut
sub classify_all {
    my ($self, $test_set) = @_;

    if(!$test_set || 'Algorithm::AM::DataSet' ne ref $test_set){
        croak q[Must provide a DataSet to classify_all];
    }
    if($self->training_set->cardinality != $test_set->cardinality){
        croak 'Training and test sets do not have the same ' .
            'cardinality (' . $self->training_set->cardinality .
                ' and ' . $test_set->cardinality . ')';
    }
    $self->_set_test_set($test_set);

    if($self->begin_hook){
        $self->begin_hook->($self);
    }

    # save the result objects from all items, all iterations, here
    my @all_results;

    foreach my $item_number (0 .. $test_set->size - 1) {
        if($log->is_debug){
            $log->debug('Test items left: ' .
                $test_set->size + 1 - $item_number);
        }
        my $test_item = $test_set->get_item($item_number);
        # store the results just for this item
        my @item_results;

        if($self->begin_test_hook){
            $self->begin_test_hook->($self, $test_item);
        }

        if($log->is_debug){
            my ( $sec, $min, $hour ) = localtime();
            $log->info(
                sprintf( "Time: %2s:%02s:%02s\n", $hour, $min, $sec) .
                (join ' ', @{$test_item->features}) . "\n" .
                sprintf( "0/$self->{repeat}  %2s:%02s:%02s",
                    $hour, $min, $sec ) );
        }

        my $iteration = 1;
        while ( $iteration <= $self->repeat ) {
            if($self->begin_repeat_hook){
                $self->begin_repeat_hook->(
                    $self, $test_item, $iteration);
            }

            # this sets excluded_items
            my ($training_set, $excluded_items) = $self->_make_training_set(
                $test_item, $iteration);

            # classify the item with the given training set and
            # configuration
            my $am = Algorithm::AM->new(
                training_set => $training_set,
                exclude_nulls => $self->exclude_nulls,
                exclude_given => $self->exclude_given,
                linear => $self->linear,
            );
            my $result = $am->classify($test_item);

            if($log->is_info){
                my ( $sec, $min, $hour ) = localtime();
                $log->info(
                    sprintf(
                        $iteration . '/' . $self->repeat .
                        '  %2s:%02s:%02s',
                        $hour, $min, $sec
                    )
                );
            }

            if($self->end_repeat_hook){
                # pass in self, test item, data, and result
                $self->end_repeat_hook->($self, $test_item,
                    $iteration, $excluded_items, $result);
            }
            push @item_results, $result;
            $iteration++;
        }

        if($self->end_test_hook){
            $self->end_test_hook->($self, $test_item, @item_results);
        }

        push @all_results, @item_results;
    }

    if($log->is_info){
        my ( $sec, $min, $hour ) = localtime();
        $log->info(
            sprintf( "Time: %2s:%02s:%02s", $hour, $min, $sec ) );
    }

    if($self->end_hook){
        $self->end_hook->($self, @all_results);
    }
    $self->_set_test_set(undef);
    return @all_results;
}

# create the training set for this iteration, calling training_data_hook and
# updating excluded_items along the way
sub _make_training_set {
    my ($self, $test_item, $iteration) = @_;
    my $training_set;

    # $self->_set_excluded_items([]);
    my @excluded_items;
    # Cap the amount of considered data if specified
    my $max = defined $self->max_training_items ?
        int($self->max_training_items) :
        $self->training_set->size;

    # use the original DataSet object if there are no settings
    # that would trim items from it
    if(!$self->training_data_hook &&
            ($self->probability == 1) &&
            $max >= $self->training_set->size){
        $training_set = $self->training_set;
    }else{
        # otherwise, make a new set with just the selected
        # items
        $training_set = Algorithm::AM::DataSet->new(
            cardinality => $self->training_set->cardinality);

        # don't try to add more items than we have!
        my $num_items = ($max > $self->training_set->size) ?
            $self->training_set->size :
            $max;
        for my $data_index ( 0 .. $num_items - 1 ) {
            my $training_item =
                $self->training_set->get_item($data_index);
            # skip this data item if the training_data_hook returns false
            if($self->training_data_hook &&
                    !$self->training_data_hook->($self,
                        $test_item, $iteration, $training_item)
                    ){
                push @excluded_items, $training_item;
                next;
            }
            # skip this data item with probability $self->{probability}
            if($self->probability != 1 &&
                    rand() > $self->probability){
                push @excluded_items, $training_item;
                next;
            }
            $training_set->add_item($training_item);
        }
    }
    # $self->_set_excluded_items(\@excluded_items);
    return ($training_set, \@excluded_items);
}

=head2 C<test_set>

Returns the test set currently providing the source of items to
classify. Before and after classify_all, this returns undef, and so is
only useful when called inside one of the hook subroutines.

=cut
sub test_set {
    my ($self) = @_;
    return $self->{test_set};
}

sub _set_test_set {
    my ($self, $test_set) = @_;
    $self->{test_set} = $test_set;
}

1;

__END__

=head2 C<probability>

Get/set the probabibility that any one data item would be included
among the training items used during classification, which is 1 by
default.

=head2 C<exclude_nulls>

Get/set true if features that are unknown in the test item should
be ignored.

=head2 C<exclude_given>

Get/set true if the test item should be removed from the training set
if found there.

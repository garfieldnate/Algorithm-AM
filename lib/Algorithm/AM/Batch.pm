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

    beginhook
    beginrepeathook
    begintesthook
    datahook
    endtesthook
    endrepeathook
    endhook
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
        beginhook
        beginrepeathook
        begintesthook
        datahook
        endtesthook
        endrepeathook
        endhook
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
    $self->_set_test_set($test_set);

    if(!$test_set || 'Algorithm::AM::DataSet' ne ref $test_set){
        croak q[Must provide a DataSet to classify_all];
    }
    if($self->training_set->cardinality != $test_set->cardinality){
        croak 'Training and test sets do not have the same ' .
            'cardinality (' . $self->training_set->cardinality .
                ' and ' . $test_set->cardinality . ')';
    }
    # save the result objects from each run here
    my @results;

    if($self->beginhook){
        $self->beginhook->($self);
    }

    foreach my $item_number (0 .. $test_set->size - 1) {
        if($log->is_debug){
            $log->debug('Test items left: ' .
                $test_set->size + 1 - $item_number);
        }
        my $test_item = $test_set->get_item($item_number);

        if($self->begintesthook){
            # pass in self and the test item
            $self->begintesthook->($self, $test_item);
        }

        my ( $sec, $min, $hour ) = localtime();
        if($log->is_debug){
            $log->info(
                sprintf( "Time: %2s:%02s:%02s\n", $hour, $min, $sec) .
                (join ' ', @{$test_item->features}) . "\n" .
                sprintf( "0/$self->{repeat}  %2s:%02s:%02s",
                    $hour, $min, $sec ) );
        }

        $self->_set_pass(1);
        while ( $self->pass <= $self->repeat ) {
            my @excluded_items = ();
            my $given_excluded = 0;
            if($self->beginrepeathook){
                $self->beginrepeathook->($self, $test_item);
            }

            my $training_set = $self->_make_training_set($test_item);

            # classify the item with the given training set and
            # configuration
            my $am = Algorithm::AM->new(
                training_set => $training_set,
                exclude_nulls => $self->exclude_nulls,
                exclude_given => $self->exclude_given,
                linear => $self->linear,
            );
            my $result = $am->classify($test_item);
            push @results, $result;
        }
        continue {
            if($self->endrepeathook){
                # pass in self, test item, data, and result
                $self->endrepeathook->($self,
                    $test_item, $results[-1]);
            }
            $self->_set_pass($self->pass() + 1);
            my ( $sec, $min, $hour ) = localtime();
            $log->info(
                sprintf(
                    $self->pass . '/' . $self->repeat .
                    '  %2s:%02s:%02s',
                    $hour, $min, $sec ) )
                if $log->is_info;
        }
        if($self->endtesthook){
            # pass in self, test item, data, and result
            $self->endtesthook->($self, $test_item, $results[-1]);
        }
    }

    my ( $sec, $min, $hour ) = localtime();
    $log->info( sprintf( "Time: %2s:%02s:%02s", $hour, $min, $sec ) )
        if $log->is_info;

    if($self->endhook){
        $self->endhook->($self, @results);
    }
    $self->_set_test_set(undef);
    return @results;
}

sub _make_training_set {
    my ($self, $test_item) = @_;
    my $training_set;

    $self->_set_excluded_items([]);
    my @excluded_items;
    # Cap the amount of considered data if specified
    my $max = defined $self->max_training_items ?
        int($self->max_training_items) :
        $self->training_set->size;

    # use the original DataSet object if there are no settings
    # that would trim items from it
    if(!$self->datahook &&
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
            # skip this data item if the datahook returns false
            if($self->datahook &&
                    !$self->datahook->($self,
                        $test_item, $training_item)
                    ){
                push @excluded_items, $data_index;
                next;
            }
            # skip this data item with probability $self->{probability}
            if($self->probability != 1 &&
                    rand() > $self->probability){
                push @excluded_items, $data_index;
                next;
            }
            $training_set->add_item($training_item);
        }
    }
    $self->_set_excluded_items(\@excluded_items);
    return $training_set;
}

=head2 C<state_summary>

Returns a scalar ref containing a printout of the current object state,
including iteration, probability, size of training and test set,
excluded items, pointer counting method, exclude given, and exclude
nulls.

=cut
sub state_summary {
    my ($self) = @_;
    my $info = "Algorithm::AM::Batch State Summary\n";
    $info .= 'Probability of including any item: '.
        $self->probability . "\n";
    $info .= 'Size of training set: ' . $self->training_set->size .
        "\n";
    $info .= 'Size of test set: ' . $self->test_set->size . "\n";
    if($self->pass){
        $info .= 'Current iteration: ' . $self->pass . "\n";
    }
    $info .= 'Pointer counting method: ' .
        ($self->linear ? 'linear' : 'quadratic') . "\n";
    if($self->excluded_items){
        $info .= 'Items excluded from training set: ' .
            (join ', ', @{$self->excluded_items}) . "\n";
    }
    $info .= 'Exclude nulls: ' .
        ($self->exclude_nulls ? 'yes' : 'no') . "\n";
    $info .= 'Exclude given: ' .
        ($self->exclude_given ? 'yes' : 'no') . "\n";
    return \$info;
}

=head2 C<test_set>

Returns the test set currently providing the source of items to
classify. This only returns something when called inside one of the
hook subroutines.

=cut
sub test_set {
    my ($self) = @_;
    return $self->{test_set};
}

sub _set_test_set {
    my ($self, $test_set) = @_;
    $self->{test_set} = $test_set;
}

=head2 C<iteration>

Returns the current iteration of classification. This is only relevant
inside of the hook subroutines, when repeat has been set higher than 1.

=cut
sub pass {
    my ($self) = @_;
    return $self->{pass};
}

sub _set_pass {
    my ($self, $pass) = @_;
    $self->{pass} = $pass;
}

=head2 C<excluded_items>

Returns an array ref containing the indices of the training items
that were excluded from training during the last classification.
The items themselves can then be retrieved using C<training_set>.
This list does not include items which were excluded because of
C<max_training_items>.

=cut

sub excluded_items {
    my ($self) = @_;
    return $self->{excluded_items};
}

sub _set_excluded_items {
    my ($self, $excluded_items) = @_;
    $self->{excluded_items} = $excluded_items;
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

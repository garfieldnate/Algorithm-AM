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
    test_set

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

    for('training_set','test_set'){
        if(!exists $args->{$_}){
            croak "Missing required parameter '$_'";
        }
        if(!(ref $args) or !$args->{$_}->isa('Algorithm::AM::DataSet')){
            croak "Parameter $_ should be an Algorithm::AM::DataSet";
        }
    }
    my ($train, $test) = ($args->{training_set}, $args->{test_set});
    if($train->vector_length != $test->vector_length){
        croak 'Training and test sets do not have the same ' .
            'cardinality (' . $train->vector_length . ' and ' .
                $test->vector_length . ')';
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
        if(exists $args->{$_} and 'SUB' ne ref $args->{$_}){
            croak "Input $_ should be a subroutine";
        }
    }
}

=head2 C<training_set>

Returns the dataset used for training.

=head2 C<test_set>

Returns the dataset used for testing.

=head2 C<classify>

Using the analogical modeling algorithm, this method classifies
the test items in the project and returns a list of
L<Result|Algorithm::AM::Result> objects. Information about the current
progress, configuration and timing is logged at the debug level.
The statistical summary, analogical set, and gang summary (without
items listed) are logged at the info level, and the full gang summary
with items listed is logged at the debug level.

=cut
sub classify {
    my ($self, %args) = @_;

    # update settings with input parameters
    $self->_set_classify_opts(%args);

    my $test_set = $self->test_set;

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

        $self->_set_pass(0);
        # Cap the amount of considered data if specified
        my $max = defined $self->max_training_items ?
            int($self->max_training_items) :
            $self->training_set->size;

        while ( $self->pass < $self->repeat ) {
            my @excluded_data = ();
            my $given_excluded = 0;
            if($self->beginrepeathook){
                $self->beginrepeathook->($self, $test_item);
            }
            # user may have set max during hook
            $max = defined $self->max_training_items ?
                int($self->max_training_items) :
                $self->training_set->size;

            # use the original DataSet object if there are no settings
            # that would trim items from it
            my $training_set;
            if(!$self->datahook &&
                    ($self->probability == 1) &&
                    $max >= $self->training_set->size){
                $training_set = $self->training_set;
            }else{
                # otherwise, make a new set with just the selected
                # items
                $training_set = Algorithm::AM::DataSet->new(
                    vector_length => $self->training_set->vector_length);

                # don't try to add more items than we have!
                my $num_items = ($max > $self->training_set->size) ?
                    $self->training_set->size :
                    $max;
                for my $data_index ( 0 .. $num_items - 1 ) {
                    # skip this data item if the datahook returns false
                    if($self->datahook &&
                            !$self->datahook->($self,
                                $test_item, $data_index)
                            ){
                        push @excluded_data, $data_index;
                        next;
                    }
                    # skip this data item with probability $self->{probability}
                    if($self->probability != 1 &&
                            rand() > $self->probability){
                        push @excluded_data, $data_index;
                        next;
                    }
                    $training_set->add_item(
                        $self->training_set->get_item($data_index));
                }
            }

            # classify the item with the given training set and
            # configuration
            my $am = Algorithm::AM->new(
                train => $training_set,
            );
            my $result = $am->classify(
                $test_item,
                exclude_nulls => $self->exclude_nulls,
                exclude_given => $self->exclude_given,
                linear => $self->linear,
            );
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
    return @results;
}

{
    # create a hash of the legal input parameters
    my @attrs = Class::Tiny->get_all_attributes_for(
        "Algorithm::AM::Batch");
    my %atts = map {$_ => 1} @attrs;
    # call setters for all input arguments, making sure they are
    # legal first
    sub _set_classify_opts {
        my ($self, %args) = @_;
        for my $key (keys %args){
            if(exists $atts{$key}){
                $self->$key($args{$key});
            }else{
                croak "Invalid attribute '$key'";
            }
        }
        return;
    }
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

1;

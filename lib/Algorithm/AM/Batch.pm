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

    #Kee track of iteration related information
    my $datacap = $self->training_set->size;
    my $pass;

    my ( $sec, $min, $hour );

    if(defined $self->beginhook){
        $self->beginhook->($self);
    }

    my $left = scalar $test_set->size;
    foreach my $item_number (0 .. $test_set->size - 1) {
        $log->debug("Test items left: $left")
            if $log->is_debug;
        --$left;
        my $test_item = $test_set->get_item($item_number);

        if(defined $self->begintesthook){
            # pass in self and the test item
            $self->begintesthook->($self, $test_item);
        }

        ( $sec, $min, $hour ) = localtime();
        if($log->is_debug){
            $log->info(
                sprintf( "Time: %2s:%02s:%02s\n", $hour, $min, $sec) .
                (join ' ', @{$test_item->features}) . "\n" .
                sprintf( "0/$self->{repeat}  %2s:%02s:%02s",
                    $hour, $min, $sec ) );
        }

        $pass = 0;
        while ( $pass < $self->repeat ) {
            my @excluded_data = ();
            my $given_excluded = 0;
            if(defined $self->beginrepeathook){
                # pass in self, test item, and data
                $self->beginrepeathook->($self,
                    $test_item, {pass => $pass, datacap => $datacap});
            }
            $datacap = int($datacap);

            # use the original DataSet object if there are no settings
            # that would trim items from it
            my $training_set;
            if(!defined $self->datahook &&
                    ($self->probability == 1) &&
                    $datacap >= $self->training_set->size){
                $training_set = $self->training_set;
            }else{
                # otherwise, make a new set
                # with just the selected items
                $training_set = Algorithm::AM::DataSet->new(
                    vector_length => $self->training_set->vector_length);
                # determine the data set to be used for classification
                for my $data_index ( 0 .. $datacap - 1 ) {
                    # skip this data item if the datahook returns false
                    if(defined $self->datahook &&
                            !$self->datahook->(
                                # pass in self, test, data and data index
                                $self,
                                $test_item,
                                {pass => $pass, datacap => $datacap},
                                 $data_index)
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
            # classify the item with the given set and configurations
            my %opts;
            for(qw(exclude_nulls exclude_given linear)){
                $opts{$_} = $self->{$_};
            }
            my $am = Algorithm::AM->new(
                train => $training_set,
            );
            my ($result) = $am->classify(
                $test_item,
                exclude_nulls => $self->exclude_nulls,
                exclude_given => $self->exclude_given,
                linear => $self->linear,
            );
            push @results, $result;
        }
        continue {
            if(defined $self->endrepeathook){
                # pass in self, test item, data, and result
                $self->endrepeathook->(
                    $self,
                    $test_item,
                    {pass => $pass, datacap => $datacap},
                    $results[-1]
                );
            }
            ++$pass;
            ( $sec, $min, $hour ) = localtime();
            $log->info(
                sprintf(
                    "$pass/$self->{repeat}  %2s:%02s:%02s",
                    $hour, $min, $sec ) )
                if $log->is_info;
        }
        if(defined $self->endtesthook){
            # pass in self, test item, data, and result
            $self->endtesthook->(
                $self,
                $test_item,
                {pass => $pass, datacap => $datacap},
                $results[-1]
            );
        }
    }

    ( $sec, $min, $hour ) = localtime();
    $log->info( sprintf( "Time: %2s:%02s:%02s", $hour, $min, $sec ) )
        if $log->is_info;

    if(defined $self->endhook){
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

1;

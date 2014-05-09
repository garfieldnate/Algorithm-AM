package Algorithm::AM::DataSet;
use strict;
use warnings;
use Carp;
use Algorithm::AM::DataSet::Item;
# ABSTRACT: Manage data used by Algorithm::AM
# VERSION;

=head2 C<new>

Creates a new DataSet object. You must provide a C<vector_length> argument
indicating the number of features to be contained in each data vector.
You can then add items via the add_data method. Each item will contain
a feature vector, and also optionally a class label and a comment
(also called a "spec").

=cut
sub new {
    my ($class, %opts) = @_;

    my $new_opts = _check_opts(%opts);

    my $self = bless $new_opts, $class;

    $self->_init;

    return $self;
}

# check the project path and the options for validity
# Return an option hash to initialize $self with, containing the
# project path object, number of variables, and field_sep and var_sep,
# which are used to parse data lines
sub _check_opts {
    my (%opts) = @_;

    my %proj_opts;

    if(!defined $opts{vector_length}){
        croak q{Failed to provide 'vector_length' parameter};
    }
    $proj_opts{vector_length} = $opts{vector_length};
    delete $opts{vector_length};

    if(keys %opts){
        # sort the keys in the error message to make testing possible
        croak 'Unknown parameters in Project constructor: ' .
            (join ', ', sort keys %opts);
    }

    return \%proj_opts;
}

# initialize internal state
sub _init {
    my ($self) = @_;
    # used to keep track of unique outcomes
    $self->{outcomes} = {};
    $self->{outcome_num} = 0;
    # index 0 of outcomelist is reserved for the AM algorithm
    $self->{outcomelist} = [''];

    $self->{items} = [];
    $self->{data} = [];
    $self->{exemplar_outcomes} = [];
    $self->{spec} = [];
    return;
}

=head2 C<vector_length>

Returns the number of features contained in a single data vector.

=cut
sub vector_length {
    my ($self) = @_;
    return $self->{vector_length};
}

=head2 C<size>

Returns the number of items in the data set.

=cut
sub size {
    my ($self) = @_;
    return scalar @{$self->{items}};
}

=head2 C<add_item>

Adds a new item to the data set. The only required argument is
'features', which should be an array ref containing the feature
vector. This method will croak if the length of this array does
not match L</vector_length>. 'class' and 'comment' arguments are
also accepted, where 'class' is the classification label and 'comment'
can be any string to be associated with the item. A missing or
undefined 'class' value is assumed to mean that the item classification
is unknown.

=cut
# adds data item to three internal arrays: outcome, data, and spec
# TODO: be able to add item objects
sub add_item {
    my ($self, %opts) = @_;

    my $item = Algorithm::AM::DataSet::Item->new(%opts);
    $self->_check_variables($item->features, $item->comment);

    if(defined $item->class){
        $self->_update_outcome_vars($item->class);
    }
    # store the new data item
    push @{$self->{spec}}, $item->comment;
    push @{$self->{data}}, $item->features;
    push @{$self->{classes}}, $item->class;
    push @{$self->{exemplar_outcomes}}, $self->{outcomes}{$item->class};
    push @{$self->{items}}, $item;
    return;
}

# check the input variable vector for size, and set the data vector
# size for this project if it isn't set yet
sub _check_variables {
    my ($self, $data, $spec) = @_;
    # check that the number of variables in @$data is correct
    if($self->vector_length != @$data){
        croak 'Expected ' . $self->vector_length .
            ' variables, but found ' . (scalar @$data) .
            " in @$data" . ($spec ? " ($spec)" : '');
    }
    return;
}

# keep track of outcomes; needs updating for every data/test item.
# Variables:
#   outcomes maps outcomes to their index in outcomelist
#   outcome_num is the total number of outcomes so far
#   outcomelist is a list of the unique outcomes
# TODO: We don't need so many of these structures, do we?
sub _update_outcome_vars {
    my ($self, $outcome) = @_;

    if(!$self->{outcomes}->{$outcome}){
        $self->{outcome_num}++;
        $self->{outcomes}->{$outcome} = $self->{outcome_num};
        push @{$self->{outcomelist}}, $outcome;
    }
    return;
}

=head2 C<get_item>

Return the item at the given index. This will be a
L<Algorithm::AM::DataSet::Item> object.

=cut
sub get_item {
    my ($self, $index) = @_;
    return $self->{items}->[$index];
}

=head2 C<num_classes>

Returns the number of different classification labels contained in
the data set.

=cut
sub num_classes {
    my ($self) = @_;
    return $self->{outcome_num};
}

=head2 C<get_outcome>

Returns the outcome string contained at a given index in outcomelist.

=cut
sub get_outcome {
    my ($self, $index) = @_;
    return $self->{outcomelist}->[$index];
}

# Used by AM.pm to retrieve the arrayref containing all of the
# outcomes for the data set (ordered the same as the data set).
sub _exemplar_outcomes {
    my ($self) = @_;
    return $self->{exemplar_outcomes};
}

1;

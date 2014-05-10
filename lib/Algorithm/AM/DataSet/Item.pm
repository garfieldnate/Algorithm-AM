package Algorithm::AM::DataSet::Item;
use strict;
use warnings;
use Carp;
our @CARP_NOT = qw(Algorithm::AM::DataSet);
use Class::Tiny qw(
    features
    class
    comment
), {
    comment => sub {
        # by default, the comment is just the data in a string, with
        # empty strings for unknown values
        join ',', map {defined $_ ? $_ : ''} @{ $_[0]->{features} }
    },
};
# ABSTRACT: A single data item for classification
# VERSION;

=head2 C<new>

Creates a new Item object. The only required argument is
'features', which should be an array ref containing the feature
vector. Each element of this array should be a string indicating the
value of the feature at the given index. 'class' and 'comment'
arguments are also accepted, where 'class' is the classification
label and 'comment' can be any string to be associated with the item.
A missing or undefined 'class' value is assumed to mean that the item
classification is unknown. Similarly, undef entries in the feature
vector are taken to indicate unknown values.

=cut
sub BUILD {
    my ($self, $args) = @_;
    if(!exists $args->{features} ||
        'ARRAY' ne ref $args->{features}){
        croak q[Must provide 'features' parameter of type array ref];
    }
    return;
}

=head2 C<class>

Returns the classification label for this item, or undef if the class
is unknown.

=head2 C<features>

Returns the feature vector for this item. This is an arrayref
containing the string value for each feature. An undefined value
indicates that the feature value is unknown.

=head2 C<comment>

Returns the comment for this item.

=head2 C<cardinality>

Returns the length of the feature vector for this item.

=cut
sub cardinality {
    my ($self) = @_;
    return scalar @{$self->features};
}
1;

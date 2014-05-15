package Algorithm::AM::DataSet::Item;
use strict;
use warnings;
use Carp;
our @CARP_NOT = qw(Algorithm::AM::DataSet);
use Exporter::Easy (
    OK => ['new_item']
);
# ABSTRACT: A single data item for classification
# VERSION;

=head1 SYNOPSIS

  use Algorithm::AM::DataSet::Item 'new_item';

  my $item = new_item(
    features => ['a', 'b', 'c'],
    class => 'x',
    comment => 'a sample, meaningless item'
  );

=head1 DESCRIPTION

This class represents a single item contained in a data set. Each
item has a feature vector and possibly a class label and comment
string. Once created, the item is immutable.

=head1 METHODS

=head2 C<new>

Creates a new Item object. The only required argument is
'features', which should be an array ref containing the feature
vector. Each element of this array should be a string indicating the
value of the feature at the given index. 'class' and 'comment'
arguments are also accepted, where 'class' is the classification
label and 'comment' can be any string to be associated with the item.
A missing or undefined 'class' value is assumed to mean that the item
classification is unknown. For the feature vector, empty strings are
taken to indicate null values.

=cut
sub new {
    my ($class, %args) = @_;
    if(!exists $args{features} ||
        'ARRAY' ne ref $args{features}){
        croak q[Must provide 'features' parameter of type array ref];
    }
    my $self = {};
    for(qw(features class comment)){
        $self->{$_} = $args{$_};
        delete $args{$_};
    }
    if(my $extra_keys = join ',', sort keys %args){
        croak "Unknown parameters: $extra_keys";
    }
    bless $self, $class;
    return $self;
}

=head2 C<new_item>

This is an exportable shortcut for the new method. If exported, then
instead of calling C<<Algorithm::AM::DataSet::Item->new>>, you may
simply call C<new_item>.

=cut
sub new_item {
    # unpack here so that warnings about odd numbers of elements are
    # reported for this function, not for the new method
    my %args = @_;
    return __PACKAGE__->new(%args);
}

=head2 C<class>

Returns the classification label for this item, or undef if the class
is unknown.

=cut
sub class {
    my ($self) = @_;
    return $self->{class};
}

=head2 C<features>

Returns the feature vector for this item. This is an arrayref
containing the string value for each feature. An empty string
indicates that the feature value is null (meaning that it has
no value).

=cut
sub features {
    my ($self) = @_;
    # make a safe copy
    return [@{ $self->{features} }];
}

=head2 C<comment>

Returns the comment for this item. By default, the comment is
just a comma-separated list of the feature values.

=cut
sub comment {
    my ($self) = @_;
    if(!defined $self->{comment}){
        $self->{comment} = join ',', @{ $self->{features} };
    }
    return $self->{comment};
}

=head2 C<cardinality>

Returns the length of the feature vector for this item.

=cut
sub cardinality {
    my ($self) = @_;
    return scalar @{$self->features};
}
1;

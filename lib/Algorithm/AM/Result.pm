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
    probability
    count_method
    datacap
);

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

1;

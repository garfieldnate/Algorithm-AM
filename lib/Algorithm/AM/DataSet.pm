package Algorithm::AM::DataSet;
use strict;
use warnings;
use Carp;
use Algorithm::AM::DataSet::Item;
use Path::Tiny;
use Exporter::Easy (
    OK => ['dataset_from_file']
);
# ABSTRACT: Manage data used by Algorithm::AM
# VERSION;

=head2 C<new>

Creates a new DataSet object. You must provide a C<cardinality> argument
indicating the number of features to be contained in each data vector.
You can then add items via the add_item method. Each item will contain
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

    my %final_opts;

    if(!defined $opts{cardinality}){
        croak q{Failed to provide 'cardinality' parameter};
    }
    $final_opts{cardinality} = $opts{cardinality};
    delete $opts{cardinality};

    if(keys %opts){
        # sort the keys in the error message to make testing possible
        croak 'Unknown parameters in DataSet constructor: ' .
            (join ', ', sort keys %opts);
    }

    return \%final_opts;
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

=head2 C<cardinality>

Returns the number of features contained in a single data vector.

=cut
sub cardinality {
    my ($self) = @_;
    return $self->{cardinality};
}

=head2 C<size>

Returns the number of items in the data set.

=cut
sub size {
    my ($self) = @_;
    return scalar @{$self->{items}};
}

=head2 C<add_item>

Adds a new item to the data set. The input may be either an
L<Algorithm::AM::DataSet::Item> object, or the arguments to create
one via its constructor (features, class, comment). This method will
croak if the cardinality of the item does not match L</cardinality>.

=cut
sub add_item {
    my ($self, @args) = @_;
    my $item;
    if('Algorithm::AM::DataSet::Item' eq ref $args[0]){
        $item = $args[0];
    }else{
        $item = Algorithm::AM::DataSet::Item->new(@args);
    }

    if($self->cardinality != $item->cardinality){
        croak 'Expected ' . $self->cardinality .
            ' variables, but found ' . (scalar $item->cardinality) .
            ' in ' . (join ' ', @{$item->features}) .
            ' (' . $item->comment . ')';
    }

    if(defined $item->class){
        $self->_update_outcome_vars($item->class);
        push @{$self->{exemplar_outcomes}},
            $self->{outcomes}{$item->class};
    }else{
        push @{$self->{exemplar_outcomes}}, undef;
    }
    # store the new data item
    push @{$self->{spec}}, $item->comment;
    push @{$self->{data}}, $item->features;
    push @{$self->{classes}}, $item->class;
    push @{$self->{items}}, $item;
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

sub _integer_outcome {
    my ($self, $index) = @_;
    return $self->{outcomes}->{$self->get_item($index)->class};
}

=head2 C<read_data>

This function may be exported. Given 'path' and 'format' arguments,
it reads a file containing a dataset and returns a new DataSet object
with the given data. The 'path' argument should be the path to the
file. The 'format' argument should be 'commas' or 'nocommas',
indicating one of the following formats. You may also specify an
'unknown' argument to indicate the string meant to represent an unknown
class value. By default this is 'UNK';

=cut
sub dataset_from_file {
    my (%opts) = (
        unknown => 'UNK',
        @_
    );

    croak q[Failed to provide 'path' parameter]
        unless exists $opts{path};
    croak q[Failed to provide 'format' parameter]
        unless exists $opts{format};

    my ($path, $format, $unknown) = (
        path($opts{path}), $opts{format}, $opts{unknown});

    croak "Could not find file $path"
        unless $path->exists;

    my ($field_sep, $feature_sep);
    if($format eq 'commas'){
        # outcome/data/spec separate by a comma
        $field_sep   = qr{\s*,\s*};
        # variables separated by space
        $feature_sep = qr{\s+};
    }elsif($format eq 'nocommas'){
        # outcome/data/spec separated by space
        $field_sep   = qr{\s+};
        # no seps for variables; each is a single character
        $feature_sep = qr{};
    }else{
        croak "Unknown value $format for format parameter " .
            q{(should be 'commas' or 'nocommas')};
    }

    if(!defined $unknown){
        croak q[Must provide a defined value for 'unknown' parameter];
    }

    my $reader = _read_data_sub(
        $path, $unknown, $field_sep, $feature_sep);
    my $item = $reader->();
    if(!$item){
        croak "No data found in file $path";
    }
    my $dataset = __PACKAGE__->new(cardinality => $item->cardinality);
    $dataset->add_item($item);
    while($item = $reader->()){
        $dataset->add_item($item);
    }
    return $dataset;
}

# return a sub that returns one data vector per call from the given FH,
# and returns undef once the data file is done being read. Throws errors
# on bad file contents.
# Input is file (Path::Tiny), string representing unknown class,
# field separator (class, features, comment) and feature separator
sub _read_data_sub {
    my ($data_file, $unknown, $field_sep, $feature_sep) = @_;
    my $data_fh = $data_file->openr_utf8;
    my $line_num = 0;
    return sub {
        my $line;
        # grab the next non-blank line from the file
        while($line = <$data_fh>){
            $line_num++;
            # cross-platform chomp
            $line =~ s/\R$//;
            $line =~ s/^\s+|\s+$//g;
            last if $line;
        }
        return unless $line;
        my ($class, $feats, $comment) = split /$field_sep/, $line, 3;
        # the line has to have at least the class label and features
        if(!defined $feats){
            croak "Couldn't read data at line $line_num in $data_file";
        }
        # if the class is specified as unknown, set it to undef to
        # indicate this to Item
        if($class eq $unknown){
            undef $class;
        }

        my @data_vars = split /$feature_sep/, $feats;
        # set unknown variables to ''
        @data_vars = map {$_ eq $unknown ? '' : $_} @data_vars;

        return Algorithm::AM::DataSet::Item->new(
            features=> \@data_vars,
            class => $class
        );
    };
}

1;

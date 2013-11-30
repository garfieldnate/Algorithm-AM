package Algorithm::AM::Project;
use strict;
use warnings;
use Path::Tiny;
use Carp;
use Log::Any '$log';

sub new {
    my ($class, $path, $opts) = @_;
    my $data_path = path($path, 'data');
    croak 'Project has no data file'
        unless $data_path->exists;

    my $self = bless $opts, $class;
    $self->{project_path} = $path;

    $log->info('Reading data file...');
    $self->_read_data_set($data_path);

    $log->info('Reading outcome file...');
    $self->_set_outcomes();

    $log->info('Reading test file...');
    $self->_read_test_set();

    $log->info('...done');

    return $self;
}

sub basepath {
    my ($self) = @_;
    return $self->{project_path};
}

sub results_path {
    my ($self) = @_;
    return '' . path($self->{project_path}, 'amcpresults');
}

# returns the number of features in a single data item
sub num_features {
    my ($self, $num) = @_;
    if($num){
        $self->{num_feats} = $num;
    }
    return $self->{num_feats};
}

# return the number of items in the data (training) set
sub num_exemplars {
    my ($self) = @_;
    return scalar @{$self->{data}};
}

# returns (and/or sets) a format string for printing the variables of
# a data item
sub var_format {
    my ($self, $var_format) = @_;
    if($var_format){
        $self->{var_format} = $var_format;
    }
    return $self->{var_format};
}

# returns (and/or sets) a format string for printing a spec string
sub spec_format {
    my ($self, $spec_format) = @_;
    if($spec_format){
        $self->{spec_format} = $spec_format;
    }
    return $self->{spec_format};
}

# returns (and/or sets) a format string for printing a "long" outcome
sub outcome_format {
    my ($self, $outcome_format) = @_;
    if($outcome_format){
        $self->{outcome_format} = $outcome_format;
    }
    return $self->{outcome_format};
}

# get/set format for printing the number of data items
sub data_format {
    my ($self, $data_format) = @_;
    if($data_format){
        $self->{data_format} = $data_format;
    }
    return $self->{data_format};
}

#read data set, setting internal variables for processing and printing
sub _read_data_set {
    my ($self, $data_path) = @_;

    my @data_set = $data_path->lines;
    $log->debug( 'Data file: ' . scalar(@data_set) );

    # the length of the longest spec
    my $longest_spec = 0;
    # the length of the longest feature of the given column
    my @feature_lengths = ((0) x 60);
    for (@data_set) {
        # cross-platform chomp
        s/[\n\r]+$//;
        my ( $outcome, $data, $spec ) = split /$self->{bigsep}/, $_, 3;
        $spec ||= $data;
        my @datavar = split /$self->{smallsep}/, $data;
        $self->_add_data($outcome, \@datavar, $spec);

        # spec_length holds length of longest spec in data set
        $longest_spec = do {
            my $l = length $spec;
            $l > $longest_spec ? $l : $longest_spec;
        };

        # feature_length is an arrayref, each index holding the length of the
        # longest feature in that column
        for my $i (0 .. $#datavar ) {
            my $l = length $datavar[$i];
            $feature_lengths[$i] = $l if $l > $feature_lengths[$i];
        }
    }

    #set format variables
    $self->spec_format(
        "%-$longest_spec.${longest_spec}s");
    $self->data_format("%" . $self->num_exemplars . ".0u");

    splice @feature_lengths, $self->num_features;
    $self->var_format(
        join " ", map { "%-$_.${_}s" } @feature_lengths);
    return;
}

# $data should be an arrayref of features
# adds data item to three internal arrays: outcome, data, and spec
sub _add_data {
    my ($self, $outcome, $data, $spec) = @_;

    # first check that the number of features in @$data is correct
    # if num_features is 0, it means it hasn't been set yet
    if(my $num = $self->num_features){
        $num == @$data or
            croak "expected $num features, but found " . (scalar @$data) .
                " in @$data" . ($spec ? " ($spec)" : '');
    }else{
        $self->num_features(scalar @$data);
    }

    # store the new data item
    push @{$self->{spec}}, $spec;
    push @{$self->{data}}, $data;
    push @{$self->{outcome}}, $outcome;
}

sub _set_outcomes {
    my ($self) = @_;
    $log->info('checking for outcome file');
    my $outcome_path = path($self->{project_path}, 'outcome');
    if ( $outcome_path->exists ) {
        my $num_outcomes = $self->_read_outcome_set($outcome_path);
        if($num_outcomes != $self->num_exemplars){
            croak 'Found ' . $self->num_exemplars . ' items in data file, ' .
                "but $num_outcomes items in outcome file.";
        }
    }
    else {
        $log->info('...will use data file');
        $self->_read_outcomes_from_data();
    }
    $log->debug('...converting outcomes to indices');
    my $max_length = 0;
    @{$self->{outcome}} = map { $self->{octonum}{$_} } @{$self->{outcome}};
    foreach (@{$self->{outcomelist}}) {
        my $l;
        $l = length;
        $max_length = $l if $l > $max_length;
    }
    # index 0 is reserved for the AM algorithm
    unshift @{$self->{outcomelist}}, '';
    $self->outcome_format("%-$max_length.${max_length}s");
    return;
}

# Returns the number of outcome items found in the outcome file and
# sets several key values in $self:
# octonum maps short outcomes to their positions in
# outcomelist, which lists all of the long outcome specs
# outcometonum similarly maps specs
#
# outcome file should have one outcome per line, with first a short
# string and then a longer one, separated by a space
sub _read_outcome_set {
    my ($self, $outcome_path) = @_;

    my @outcome_set = $outcome_path->lines;

    # octonum maps short outcomes to the index of their (first)
    #   long version listed in in outcomelist
    # outcometonum maps long outcomes to the same to their own
    #   (first) position in outcomelist
    # outcomelist will hold list of all long outcome strings in file
    my $counter = 0;
    for my $outcome (@outcome_set) {
        #cross-platform chomp
        $outcome =~ s/[\n\r]+$//;
        my ( $short, $long ) = split /\s+/, $outcome, 2;
        $counter++;
        $self->{octonum}{$short}   ||= $counter;
        $self->{outcometonum}{$long} ||= $counter;
        push @{$self->{outcomelist}}, $long;
    }
    return $counter;
}

# sets several key values in $self:
#
# octonum and outcometonum both map outcome names (from the data file)
# to their positions in outcomelist, which is a sorted list of all of
#   the unique outcomes
# outcomecounter is the number of unique outcomes
sub _read_outcomes_from_data {
    my ($self) = @_;

    # Use a hash (%oc) to obtain a list of unique outcomes
    my %oc;
    $_++ for @oc{ @{$self->{outcome}} };

    my $counter;
    # sort the keys to maintain the same ordering across multiple runs
    for(sort {lc($a) cmp lc($b)} keys %oc){
        $counter++;
        $self->{octonum}{$_} = $counter;
        $self->{outcometonum}{$_} = $counter;
        push @{$self->{outcomelist}}, $_;
    }

    return;
}

sub _read_test_set {
    my ($self) = @_;
    my $test_file = path($self->{project_path}, 'test');
    if(!$test_file->exists){
        carp "Couldn't open $test_file";
        $log->warn(qq{Couldn't open $test_file; } .
            q{will run data file against itself});
        $test_file = path($self->{project_path}, 'data');
    }
    for my $t ($test_file->lines){
        #cross-platform chomp
        $t =~ s/[\n\r]+$//;
        my ($outcome, $data, $spec ) = split /$self->{bigsep}/, $t, 3;
        my @vector = split /$self->{smallsep}/, $data;
        # warn join ',', @vector;
        if($self->num_features != @vector){
            croak 'expected ' . $self->num_features . ' features, but found ' .
                (scalar @vector) . " in @vector" . ($spec ? " ($spec)" : '');
        }

        push @{$self->{testItems}}, [$outcome, \@vector, $spec || '']
    }
    return;
}

1;

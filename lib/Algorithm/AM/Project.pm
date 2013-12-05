package Algorithm::AM::Project;
use strict;
use warnings;
use Path::Tiny;
use Carp;
use Log::Any '$log';

sub new {
    my ($class, $path, %opts) = @_;

    my $new_opts = _check_opts($path, %opts);

    my $self = bless $new_opts, $class;

    $log->info('Reading data file...');
    $self->_read_data_set();

    $log->info('Reading outcome file...');
    $self->_set_outcomes();

    $log->info('Reading test file...');
    $self->_read_test_set();

    $log->info('...done');

    return $self;
}

# check the project path and the options for validity
# currently "commas" is the only accepted option
# Return an option hash to initialize $self with, containing the
# project path object and bigsep and smallsep, which are used to
# parse data lines
sub _check_opts {
    my ($path, %opts) = @_;

    croak 'Must specify project'
        unless $path;
    $path = path($path);

    croak "Could not find project $path"
        unless $path->exists;

    croak 'Project has no data file'
        unless path($path, 'data')->exists;

    croak "Failed to provide 'commas' parameter (should be 'yes' or 'no')"
        unless exists $opts{commas};

    my %proj_opts = (project_path => $path);
    if($opts{commas} eq 'yes'){
        $proj_opts{bigsep}   = qr{\s*,\s*};
        $proj_opts{smallsep} = qr{\s+};
    }elsif($opts{commas} eq 'no'){
        $proj_opts{bigsep}   = qr{\s+};
        $proj_opts{smallsep} = qr{};
    }else{
        croak "Failed to specify comma formatting correctly;\n" .
            q{(must specify commas => 'yes' or commas => 'no')};
    }

    delete $opts{commas};
    if(keys %opts){
        # sort the keys in the error message to make testing possible
        croak 'Unknown parameters in Project constructor: ' .
            (join ', ', sort keys %opts);
    }

    return \%proj_opts;
}

sub base_path {
    my ($self) = @_;
    return $self->{project_path};
}

sub results_path {
    my ($self) = @_;
    return '' . path($self->{project_path}, 'amcpresults');
}

# returns the number of variables in a single data item
sub num_variables {
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

# TODO: create an Exemplar class to hold all of this info

# returns the exemplar data vector at index $index.
# TODO: For now, using an index might be
# a little arbitrary. Might want to officially treat the index as the item's
# id
sub get_exemplar_data {
    my ($self, $index) = @_;
    return $self->{data}->[$index];
}

# returns the spec of the exemplar at index $index.
# TODO: For now, using an index might be
# a little arbitrary. Might want to officially treat the index as the item's
# id
sub get_exemplar_spec {
    my ($self, $index) = @_;
    return $self->{spec}->[$index];
}

# returns the outcome of the exemplar at index $index.
# TODO: For now, using an index might be
# a little arbitrary. Might want to officially treat the index as the item's
# id
sub get_exemplar_outcome {
    my ($self, $index) = @_;
    return $self->{outcome}->[$index];
}

# return the number of test items in the project test or data file
sub num_test_items {
    my ($self) = @_;
    return scalar @{$self->{testItems}};
}

# return the test item at the given index;
# A test item is [outcome, [data], spec]
sub get_test_item {
    my ($self, $index) = @_;
    return $self->{testItems}->[$index];
}

#Return the number of different outcomes contained in the data
sub num_outcomes {
    my ($self) = @_;
    return scalar @{$self->{outcomelist}};
}

#Return the "long" outcome string contained at a given index
sub get_outcome {
    my ($self, $index) = @_;
    return $self->{outcomelist}->[$index];
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

#returns the index of the given "short" outcome in outcomelist
sub short_outcome_index {
    my ($self, $outcome) = @_;
    return $self->{octonum}{$outcome};
}

# Used by AM.pm to retrieve the arrayref containing all of the "short"
# outcomes for the data set (ordered the same as the data set).
sub _outcomes {
    my ($self) = @_;
    return $self->{outcome};
}

# Used by AM.pm to retrieve the arrayref containing all of the
# specs for the data set (ordered the same as the data set).
sub _specs {
    my ($self) = @_;
    return $self->{spec};
}

# Used by AM.pm to retrieve the arrayref containing all of the
# data vectors for the data set (ordered the same as the data set).
sub _data {
    my ($self) = @_;
    return $self->{data};
}

# Used by AM.pm to retrieve the 1-indexed list of all "long" outcomes
# (or "short" if there was no data file)
sub _outcome_list {
    my ($self) = @_;
    return $self->{outcomelist};
}

# Used by AM.pm to retrieve the hashref mapping "long" outcome names to
# their index in outcomelist
# Hopefully won't need someday (but for now it is required for hook
# variables)
sub _outcome_to_num {
    my ($self) = @_;
    return $self->{outcometonum};
}

#read data set, calling _add_data for each item found in the data file.
#Also set spec_format, data_format and var_format.
sub _read_data_set {
    my ($self) = @_;

    my $data_path = path($self->{project_path}, 'data');

    my @data_set = $data_path->lines;
    $log->debug( 'Data file: ' . scalar(@data_set) );

    # the length of the longest spec
    my $longest_spec = 0;
    # the lengths of the longest variables in each column
    my @longest_variables = ((0) x 60);
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

        # variable_length is an arrayref, each index holding the length of the
        # longest variable in that column
        for my $i (0 .. $#datavar ) {
            my $l = length $datavar[$i];
            $longest_variables[$i] = $l if $l > $longest_variables[$i];
        }
    }

    #set format variables
    $self->spec_format(
        "%-$longest_spec.${longest_spec}s");
    $self->data_format("%" . $self->num_exemplars . ".0u");

    splice @longest_variables, $self->num_variables;
    $self->var_format(
        join " ", map { "%-$_.${_}s" } @longest_variables);
    return;
}

# $data should be an arrayref of variables
# adds data item to three internal arrays: outcome, data, and spec
sub _add_data {
    my ($self, $outcome, $data, $spec) = @_;

    # first check that the number of variables in @$data is correct
    # if num_variables is 0, it means it hasn't been set yet
    if(my $num = $self->num_variables){
        $num == @$data or
            croak "Expected $num variables, but found " . (scalar @$data) .
                " in @$data" . ($spec ? " ($spec)" : '');
    }else{
        $self->num_variables(scalar @$data);
    }

    # store the new data item
    push @{$self->{spec}}, $spec;
    push @{$self->{data}}, $data;
    push @{$self->{outcome}}, $outcome;
}

# figure out what all of the possible outcomes are
sub _set_outcomes {
    my ($self) = @_;

    #grab outcomes from either outcome file or existing data
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
# octonum, outcomelist, and outcometonum
#
# outcome file should have one outcome per line, with first a short
# string and then a long one, separated by a space.
# TODO: The first column is apparently redundant information, since
# it must also be listed in the data file.
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

# uses the outcomes from the data file for both "short"
# and "long" outcome names
#
# sets several key values in $self:
# octonum, outcomelist, and outcometonum
sub _read_outcomes_from_data {
    my ($self) = @_;

    # Use a hash (%oc) to obtain a list of unique outcomes
    my %oc;
    $_++ for @oc{ @{$self->{outcome}} };

    my $counter = 0;
    # sort the keys to maintain the same ordering across multiple runs
    for(sort {lc($a) cmp lc($b)} keys %oc){
        $counter++;
        $self->{octonum}{$_} = $counter;
        $self->{outcometonum}{$_} = $counter;
        push @{$self->{outcomelist}}, $_;
    }

    return;
}

# Sets the testItems to an arrayref of [outcome, [data], spec] for each
# item in the test file (or data file if there is none)
# test file, like the data file, should have "short" outcome, data vector,
# and a spec
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
        if($self->num_variables != @vector){
            croak 'expected ' . $self->num_variables . ' variables, but found ' .
                (scalar @vector) . " in @vector" . ($spec ? " ($spec)" : '');
        }

        push @{$self->{testItems}}, [$outcome, \@vector, $spec || '']
    }
    return;
}

1;

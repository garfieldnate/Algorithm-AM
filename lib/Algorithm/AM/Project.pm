package Algorithm::AM::Project;
use strict;
use warnings;
use Path::Tiny;
use Carp;
use Log::Any '$log';
# ABSTRACT: Manage data used by Algorithm::AM
# VERSION;

=head2 C<new>

Creates a new Project object. Pass in the path to the project directory
followed by any named arguments (currently only the required C<commas>
parameter is accepted).

A project directory should contain the data set, the test set, and the
outcome file (named, not surprisingly, F<data>, F<test>, and F<outcome>).
Each line of the data and test files should represent a single
exemplar. The required format of each line depends on the value of the
C<commas> parameter. C<< commas => 'yes' >> indicates the following
style:

    outcome   ,   v a r i a b l e s   ,   spec

where commas are used to separate the outcome, exemplar variables
and spec (or comment), and spaces are used to separate the exemplar
variables. C<< commas => 'no' >> indicates the following style:

    outcome variables spec

where spaces separate the outcome, variables and spec, and the
exemplar variables are each a single character (so the above
variables would still be C<v>, C<a>, C<r>, etc.).

Any other value for the C<commas> parameter will result in an
exception.

The outcome file should have the same number of lines as the data file,
and each line should have the outcome of the item on the same line in
the data file. The format of the outcome file is like this:

    A V-i
    B a-oi
    C tV-si

where each line contains an outcome in a "short" and then "long"
form, separated by whitespace.

If the test or outcome files are missing, the data file will be used.
In the case of a missing test file, test items will be taken from the
data file and each classified using all of the other items in the data
set. If the outcome file is missing, the outcome strings located in the
data file will be used for both long and short outcome values.

When this constructor is called, all project files are read and checked
for errors. Possible errors in your files include the following:

=over

=item *

Your project path does not exist or does not contain a data file.

=item *

The number of variables in each of the items in your test and
data files are not all the same.

=item *

The number of items in your outcome file does not match the number
of items in your data file.

=item *

TODO: A line from your data, test or outcome file could not be parsed.

=back

=cut
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

=head2 C<base_path>

Returns the path of the directory containing the project files.

=cut
sub base_path {
    my ($self) = @_;
    return $self->{project_path};
}

=head2 C<results_path>

Returns the path of the file where classification results are to be
printed. Currently this is C<amcpresults> inside of the project
directory.

=cut
sub results_path {
    my ($self) = @_;
    return '' . path($self->{project_path}, 'amcpresults');
}

=head2 C<num_variables>

Returns the number of variables contained in a single exemplar
in the project.

=cut
sub num_variables {
    my ($self, $num) = @_;
    if($num){
        $self->{num_feats} = $num;
    }
    return $self->{num_feats};
}


=head2 C<num_exemplars>

Returns the number of items in the data (training) set.

=cut
sub num_exemplars {
    my ($self) = @_;
    return scalar @{$self->{data}};
}

# TODO: create an Exemplar class to hold all of this info

# TODO: For now, using an index might be
# a little arbitrary. Might want to officially treat the index as the item's
# id

=head2 C<get_exemplar_data>

Returns the data variables for the exemplar at the given index. The
return value is an arrayref containing the string value for each
variable.

=cut
sub get_exemplar_data {
    my ($self, $index) = @_;
    return $self->{data}->[$index];
}

=head2 C<get_exemplar_spec>

Returns the spec of the exemplar at the given index.

=cut
sub get_exemplar_spec {
    my ($self, $index) = @_;
    return $self->{spec}->[$index];
}

=head2 C<get_exemplar_outcome>

Returns the outcome of the exemplar at the given index.

=cut
sub get_exemplar_outcome {
    my ($self, $index) = @_;
    return $self->{outcome}->[$index];
}

=head2 C<num_test_items>

Returns the number of test items in the project test or data file

=cut
sub num_test_items {
    my ($self) = @_;
    return scalar @{$self->{testItems}};
}

=head2 C<get_test_item>

Return the test item at the given index. The structure
of the return value is C<[outcome, [data], spec]>, where
C<[data]> contains the varaiable values.

=cut
sub get_test_item {
    my ($self, $index) = @_;
    return $self->{testItems}->[$index];
}


=head2 C<num_outcomes>

Returns the number of different outcomes contained in the data.

=cut
sub num_outcomes {
    my ($self) = @_;
    return scalar @{$self->{outcomelist}} - 1;
}


=head2 C<get_outcome>

Returns the "long" outcome string contained at a given index in
outcomelist.

=cut
sub get_outcome {
    my ($self, $index) = @_;
    return $self->{outcomelist}->[$index];
}

=head2 C<var_format>

Returns (and/or sets) a format string for printing the variables of
a data item.

=cut
sub var_format {
    my ($self, $var_format) = @_;
    if($var_format){
        $self->{var_format} = $var_format;
    }
    return $self->{var_format};
}

=head2 C<spec_format>

Returns (and/or sets) a format string for printing a spec string from
the data set.

=cut
sub spec_format {
    my ($self, $spec_format) = @_;
    if($spec_format){
        $self->{spec_format} = $spec_format;
    }
    return $self->{spec_format};
}

=head2 C<outcome_format>

Returns (and/or sets) a format string for printing a "long" outcome.

=cut
sub outcome_format {
    my ($self, $outcome_format) = @_;
    if($outcome_format){
        $self->{outcome_format} = $outcome_format;
    }
    return $self->{outcome_format};
}


=head2 C<data_format>

Returns (and/or sets) the format string for printing the number of
data items

=cut
sub data_format {
    my ($self, $data_format) = @_;
    if($data_format){
        $self->{data_format} = $data_format;
    }
    return $self->{data_format};
}

=head2 C<short_outcome_index>

Returns the index of the given "short" outcome in outcomelist.

This is obviously not very transparent, as outcomelist is only
accessible via a private method. In the future this will be
done away with.

=cut
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
    my $data_sub = $self->_read_data_sub($data_path->openr_utf8);

    # my @data_set = $data_path->lines;

    # total lines in data file
    my $num_lines = 0;
    # the length of the longest spec
    my $longest_spec = 0;
    # the lengths of the longest variables in each column
    my @longest_variables = ((0) x 60);
    while (my ($outcome, $data, $spec) = $data_sub->()) {
        $num_lines++;
        $self->_add_data($outcome, $data, $spec);

        # spec_length holds length of longest spec in data set
        $longest_spec = do {
            my $l = length $spec;
            $l > $longest_spec ? $l : $longest_spec;
        };

        # variable_length is an arrayref, each index holding the length of the
        # longest variable in that column
        for my $i (0 .. $#$data ) {
            my $l = length $data->[$i];
            $longest_variables[$i] = $l if $l > $longest_variables[$i];
        }
    }
    $log->debug( 'Data file: ' . $num_lines );

    #set format variables
    $self->spec_format(
        "%-$longest_spec.${longest_spec}s");
    $self->data_format("%" . $self->num_exemplars . ".0u");

    splice @longest_variables, $self->num_variables;
    $self->var_format(
        join " ", map { "%-$_.${_}s" } @longest_variables);
    return;
}

# return a sub that returns one data vector per call from the given FH,
# and returns undef once the data file is done being read. Throws errors
# on bad file contents. Long outcomes will be identical to short ones.
sub _read_data_sub {
    my ($self, $data_fh) = @_;
    return sub {
        my $line = <$data_fh>;
        return unless $line;
        # cross-platform chomp
        $line =~ s/[\n\r]+$//;
        my ( $outcome, $data, $spec ) = split /$self->{bigsep}/, $line, 3;
        $spec ||= $data;
        my @data_vars = split /$self->{smallsep}/, $data;
        return ($outcome, \@data_vars, $spec);
    };
}

# return a sub that reads one line of the input outcome file FH
# per call. Dies on bad file contents.
sub _read_outcome_sub {
    my ($self, $outcome_fh) = @_;
    return sub {
        my $line = <$outcome_fh>;
        return unless $line;
        #cross-platform chomp
        $line =~ s/[\n\r]+$//;
        my ( $short, $long ) = split /\s+/, $line, 2;
        return ($short, $long);
    };
}

# return a sub that returns one data vector at a time, and returns
# undef once the data and outcome file are done being read. Throws
# errors on bad file contents or different file sizes.
sub _read_data_outcome_sub {
    my ($self, $data_fh, $outcome_fh) = @_;
    my $data_sub = $self->_read_data_sub;
    my $outcome_sub = $self->_read_outcome_sub;
    return sub {

    };
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
    return;
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

    # my @outcome_set = $outcome_path->lines;
    my $outcome_sub = $self->_read_outcome_sub($outcome_path->openr_utf8);
    # octonum maps short outcomes to the index of their (first)
    #   long version listed in in outcomelist
    # outcometonum maps long outcomes to the same to their own
    #   (first) position in outcomelist
    # outcomelist will hold list of all long outcome strings in file
    my $counter = 0;
    my $outcome_num = 0;
    my %outcomes;
    while (my ($short, $long) = $outcome_sub->()) {
        $counter++;
        if(!$outcomes{$long}){
            $outcome_num++;
            $outcomes{$long} = $outcome_num;
            $self->{outcometonum}{$long} ||= $outcome_num;
            push @{$self->{outcomelist}}, $long;
        }
        $self->{octonum}{$short}   ||= $outcome_num;
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

package Algorithm::AM::Project;
use strict;
use warnings;
use Path::Tiny;
use Carp;
use Log::Any '$log';
# ABSTRACT: Manage data used by Algorithm::AM
# VERSION;

=head2 C<new>

Creates a new Project object. You may optionally pass in the path to
the project directory, followed by any named arguments (currently only
the required C<commas> parameter is accepted).

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

    # without a path, no option processing is needed
    my $new_opts = $path ?
        _check_opts($path, %opts) :
        {project_path => Path::Tiny->cwd};

    my $self = bless $new_opts, $class;

    $self->_init;

    # read project files if they exist
    if($path){
        $log->info('Reading data file...');
        $self->_read_data_set();

        $log->info('Reading test file...');
        $self->_read_test_set();

        $log->info('...done');
    }

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

# initialize internal state
sub _init {
    my ($self) = @_;
    # length of the longest spec string
    $self->{longest_spec} = 0;
    # length of the longest outcome string
    $self->{longest_outcome} = 0;
    # used to keep track of unique outcomes
    $self->{outcomes} = {};
    $self->{outcome_num} = 0;
    # index 0 of outcomelist is reserved for the AM algorithm
    $self->{outcomelist} = [''];
    # 0 means number of data columns has not been determined
    $self->{num_feats} = 0;

    $self->{testItems} = [];
    $self->{data} = [];
    $self->{outcome} = [];
    $self->{spec} = [];
    return;
}

=head2 C<base_path>

Returns the path of the directory containing the project files,
or the current working directory at the time of project creation
if no project directory was specified.

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
    my ($self) = @_;
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

TODO: this should probably make a safe copy

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
    return $self->{outcome_num};
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

Returns a format string for printing the variables of
a data item.

=cut
sub var_format {
    my ($self) = @_;

    if(!$self->num_variables){
        croak "must add data before calling var_format";
    }

    return join " ", map { "%-$_.${_}s" }
        @{ $self->{longest_variables} };
}

=head2 C<spec_format>

Returns a format string for printing a spec string from the data set.

=cut
sub spec_format {
    my ($self) = @_;

    if(!$self->num_variables){
        croak "must add data before calling spec_format";
    }

    my $length = $self->{longest_spec};
    return "%-$length.${length}s";
}

=head2 C<outcome_format>

Returns (and/or sets) a format string for printing a "long" outcome.

=cut
sub outcome_format {
    my ($self) = @_;

    if(!$self->num_variables){
        croak "must add data before calling outcome_format";
    }

    my $length = $self->{longest_outcome};
    return "%-$length.${length}s";
}


=head2 C<data_format>

Returns the format string for printing the number of data items.

=cut
sub data_format {
    my ($self) = @_;

    if(!$self->num_variables){
        croak "must add data before calling data_format";
    }

    return '%' . $self->num_exemplars . '.0u';
}

=head2 C<short_outcome_index>

Returns the index of the given "short" outcome in outcomelist, or
-1 if it is not in the list.

This is obviously not very transparent, as outcomelist is only
accessible via a private method. In the future this will be
done away with.

=cut
sub short_outcome_index {
    my ($self, $outcome) = @_;
    if(exists $self->{octonum}{$outcome}){
        return $self->{octonum}{$outcome};
    }
    return -1;
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

#read data set, calling add_data for each item found in the data file.
#Also set spec_format, data_format and var_format.
# Sets octonum, outcomelist, and outcometonum
sub _read_data_set {
    my ($self) = @_;

    my $data_path = path($self->{project_path}, 'data');
    $log->info('checking for outcome file');
    my $outcome_path = path($self->{project_path}, 'outcome');
    # $data_sub will either read data file or data file and outcome file
    my $data_sub;
    if ( $outcome_path->exists ) {
        $data_sub = $self->_read_data_outcome_sub(
            $data_path->openr_utf8, $outcome_path->openr_utf8);
    }
    else {
        $log->info('...will use data file');
        $data_sub = $self->_read_data_sub($data_path->openr_utf8);
    }

    while (my ($data, $spec, $short, $long) = $data_sub->()) {
        $self->add_data($data, $spec, $short, $long);
    }
    $log->debug( 'Data file: ' . $self->num_exemplars );

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
        $line =~ s/\R$//;
        my ( $outcome, $data, $spec ) = split /$self->{bigsep}/, $line, 3;
        $spec ||= $data;
        my @data_vars = split /$self->{smallsep}/, $data;
        # return $outcome twice for "short" and "long" versions
        return (\@data_vars, $spec, $outcome);
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
        $line =~ s/\R$//;
        my ( $short, $long ) = split /\s+/, $line, 2;
        return ($short, $long);
    };
}

# return a sub that returns one data vector at a time, and returns
# undef once the data and outcome file are done being read. Throws
# errors on bad file contents or different file sizes.
sub _read_data_outcome_sub {
    my ($self, $data_fh, $outcome_fh) = @_;
    my $data_sub = $self->_read_data_sub($data_fh);
    my $outcome_sub = $self->_read_outcome_sub($outcome_fh);
    return sub {
        # becomes obvious here that data file and outcome file have
        # redundant information
        my ($short, $long) = $outcome_sub->();
        my ($data, $spec) = $data_sub->();
        if($short xor $data){
            croak 'Number of items in data and outcome file do not match';
        }
        if($short){
            return ($data, $spec, $short, $long);
        }
        return;
    };
}

=head2 C<add_data>

Adds the arguments as a new data exemplar. There are four required
arguments: an array ref containing the data variables, the spec, the
short outcome string, and the long outcome string.

=cut
# $data should be an arrayref of variables
# adds data item to three internal arrays: outcome, data, and spec
sub add_data {
    my ($self, $data, $spec, $short, $long) = @_;
    $spec ||= _serialize_data($data);

    $self->_check_variables($data, $spec);
    $self->_update_format_vars($data, $spec, $short, $long);
    $self->_update_outcome_vars($short, $long);

    # store the new data item
    push @{$self->{spec}}, $spec;
    push @{$self->{data}}, $data;
    push @{$self->{outcome}}, $self->{octonum}{$short};
    return;
}

# check the input variable vector for size, and set the data vector
# size for this project if it isn't set yet
sub _check_variables {
    my ($self, $data, $spec) = @_;
    # check that the number of variables in @$data is correct
    # if num_variables is 0, it means it hasn't been set yet
    if(my $num = $self->num_variables){
        $num == @$data or
            croak "Expected $num variables, but found " . (scalar @$data) .
                " in @$data" . ($spec ? " ($spec)" : '');
    }else{
        # if not 0, store number of variables and expect all future
        # data vectors to be the same length
        if(@$data == 0){
            croak "Found 0 data variables in input" .
                ($spec ? " ($spec)" : '');
        }
        $self->{num_feats} = scalar @$data;
    }
    return;
}

# update format variables used for printing;
# needs updating every data item.
sub _update_format_vars {
    my ($self, $data, $spec, $short, $long) = @_;
    defined($long) or $long = $short;

    if((my $l = length $spec) > $self->{longest_spec}){
        $self->{longest_spec} = $l;
    }

    # longest_variables is an arrayref, each index holding the
    # length of the longest variable in that column.
    # Initialize it on addition of first data item.
    if(!$self->{longest_variables}[0]){
        $self->{longest_variables} = [((0) x scalar @$data)]
    }
    for my $i (0 .. $#$data ) {
        my $l = length $data->[$i];
        $self->{longest_variables}[$i] = $l
            if $l > $self->{longest_variables}[$i];
    }

    if( (my $l = length $long) > $self->{longest_outcome}) {
        $self->{longest_outcome} = $l;
    }
    return;
}


# keep track of outcomes; needs updating for every data/test item.
# Variables:
#   outcomes is a hash of the outcomes used for tracking unique
#     values
#   outcome_num is the total number of outcomes so far
#   outcometonum is the index of a "long" outcome in outcomelist
#   octonum is the index of a "short" outcome in outcomelist
#   outcomelist is a list of the unique outcomes
sub _update_outcome_vars {
    my ($self, $short, $long) = @_;

    defined($long) or $long = $short;

    if(!$self->{outcomes}->{$long}){
        $self->{outcome_num}++;
        $self->{outcomes}->{$long} = $self->{outcome_num};
        $self->{outcometonum}{$long} ||= $self->{outcome_num};
        push @{$self->{outcomelist}}, $long;
    }
    $self->{octonum}{$short}   ||= $self->{outcome_num};
    return;
}

# Sets the testItems to an arrayref of [outcome, [data], spec] for each
# item in the test file (or data file if there is none). outcome is
# the index in outcomelist.
# The test file, like the data file, should have "short" outcome,
# data vector, and a spec.
sub _read_test_set {
    my ($self) = @_;
    my $test_file = path($self->{project_path}, 'test');
    if($test_file->exists){
        my $test_sub = $self->_read_data_sub($test_file->openr_utf8);
        while(my ($data, $spec, $outcome) = $test_sub->()){
            $self->add_test($data, $spec, $outcome);
        }
    }else{
        carp "Couldn't open $test_file";
        $log->warn(qq{Couldn't open $test_file; } .
            q{will run data file against itself});
        # we don't need the extra processing of add_test
        @{$self->{testItems}} = map {[
            $self->{outcome}->[$_],
            $self->{data}->[$_],
            $self->{spec}->[$_]
        ]} (0 .. $self->num_exemplars);
    }
    return;
}

=head2 C<add_test>

Add a test item to the project. The arguments are the same as for
c<add_data>.

=cut
sub add_test {
    my ($self, $data, $spec, $short, $long) = @_;
    # TODO: make sure outcome exists in index

    $self->_check_variables($data, $spec);
    # if it's a new outcome, add it to the list
    if($self->short_outcome_index($short) == -1){
        $self->_update_outcome_vars($short, $long);
    }
    push @{$self->{testItems}}, [
        $self->short_outcome_index($short),
        $data,
        $spec || _serialize_data($data)
        ];
    return;
}

# return a simple string representation for data arrays
sub _serialize_data {
    my ($data) = @_;
    return join ' ', @$data;
}

1;

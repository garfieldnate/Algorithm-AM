package Algorithm::AM::Project;
use strict;
use warnings;
use Path::Tiny;
use Carp;
use Log::Any '$log';
# ABSTRACT: Manage data used by Algorithm::AM
# VERSION;

=head2 C<new>

Creates a new Project object. You must provide a C<variables> argument
indicating the number of variables in a given data vector.
You may provide a C<path> argument
indicating the location of a project directory. If this is specified,
you must also specify a C<commas> parameter to indicate the file
format:

 my $project = Algorithm::AM::Project->new(
     variables => 4, 'path/to/project', commas => 0);

A project directory should contain the data set and the test set
(named, not surprisingly, F<data> and F<test>).
Each line of the data and test files should represent a single
exemplar. The required format of each line depends on the value of the
C<commas> parameter. C<< commas => 1 >> indicates the following
style:

    outcome   ,   v a r i a b l e s   ,   spec

where commas are used to separate the outcome, exemplar variables
and spec (or comment), and spaces are used to separate the exemplar
variables. C<< commas => 0 >> indicates the following style:

    outcome variables spec

where spaces separate the outcome, variables and spec, and the
exemplar variables are each a single character (so the above
variables would still be C<v>, C<a>, C<r>, etc.).

Any other value for the C<commas> parameter will result in an
exception.

If the test file is missing, the data file will be used, and each item
will be classified using all of the other items in the data
set.

When this constructor is called, all project files are read and checked
for errors. Possible errors in your files include the following:

=over

=item *

Your project path does not exist or does not contain a data file.

=item *

The number of variables in each of the items in your test and
data files are not all the same.

=item *

TODO: A line from your data or test could not be parsed.

=back

=cut
sub new {
    my ($class, %opts) = @_;

    # without a path, no option processing is needed
    my $new_opts = _check_opts(%opts);

    my $self = bless $new_opts, $class;

    $self->_init;

    # read project files if they exist
    if($self->base_path){
        $log->info('Reading data file...');
        $self->_read_data_set();

        $log->info('Reading test file...');
        $self->_read_test_set();

        $log->info('...done');
    }

    return $self;
}

# check the project path and the options for validity
# Return an option hash to initialize $self with, containing the
# project path object, number of variables, and field_sep and var_sep,
# which are used to parse data lines
sub _check_opts {
    my (%opts) = @_;

    my %proj_opts;
    # process path to data project if provided
    # if project path is given, check its validity and check commas
    # parameter
    if(exists $opts{path}){
        my $path = path($opts{path});
        croak "Could not find project $path"
            unless $path->exists;
        croak 'Project has no data file'
            unless path($path, 'data')->exists;
        delete $opts{path};
        %proj_opts = (path => $path);

        croak "Failed to provide 'commas' parameter"
            unless exists $opts{commas};

        if($opts{commas}){
            $log->info('Parsing data with commas file format')
                if $log->is_info;
            # outcome/data/spec separate by a comma
            $proj_opts{field_sep}   = qr{\s*,\s*};
            # variables separated by space
            $proj_opts{var_sep} = qr{\s+};
        }else{
            $log->info('Parsing data with no-commas file format')
                if $log->is_info;
            # outcome/data/spec separated by space
            $proj_opts{field_sep}   = qr{\s+};
            # no seps for variables; each is a single character
            $proj_opts{var_sep} = qr{};
        }
        delete $opts{commas};
    }

    if(!defined $opts{variables}){
        croak q{Failed to provide 'variables' parameter};
    }
    $proj_opts{num_feats} = $opts{variables};
    delete $opts{variables};

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

    $self->{testItems} = [];
    $self->{data} = [];
    $self->{exemplar_outcomes} = [];
    $self->{spec} = [];
    return;
}

=head2 C<base_path>

Returns the path of the directory containing the project files, or
undef if no such directory was used.

=cut
sub base_path {
    my ($self) = @_;
    return $self->{path};
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
    return $self->{exemplar_outcomes}->[$index];
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

Returns the outcome string contained at a given index in outcomelist.

=cut
sub get_outcome {
    my ($self, $index) = @_;
    return $self->{outcomelist}->[$index];
}

=head2 C<outcome_index>

Returns the index of the given outcome in outcomelist, or
-1 if it is not in the list.

This is obviously not very transparent, as outcomelist is only
accessible via a private method. In the future this will be
done away with.

=cut
sub outcome_index {
    my ($self, $outcome) = @_;
    if(exists $self->{outcomes}{$outcome}){
        return $self->{outcomes}{$outcome};
    }
    return -1;
}

# Used by AM.pm to retrieve the arrayref containing all of the
# outcomes for the data set (ordered the same as the data set).
sub _exemplar_outcomes {
    my ($self) = @_;
    return $self->{exemplar_outcomes};
}

# Used by AM.pm to retrieve the arrayref containing all of the
# specs for the data set (ordered the same as the data set).
sub _exemplar_specs {
    my ($self) = @_;
    return $self->{spec};
}

# Used by AM.pm to retrieve the arrayref containing all of the
# data vectors for the data set (ordered the same as the data set).
sub _exemplar_vars {
    my ($self) = @_;
    return $self->{data};
}

# Used by AM.pm to retrieve the 1-indexed list of all outcomes
sub _outcome_list {
    my ($self) = @_;
    return $self->{outcomelist};
}

# Used by AM.pm to retrieve the hashref mapping outcome names to
# their index in outcomelist
# Hopefully won't need someday (but for now it is required for hook
# variables)
sub _outcome_to_num {
    my ($self) = @_;
    return $self->{outcomes};
}

# read data set, calling add_data for each item found in the data file.
sub _read_data_set {
    my ($self) = @_;

    my $data_path = path($self->base_path, 'data');

    my $data_sub = $self->_read_data_sub($data_path);
    while(my ($data, $spec, $outcome) = $data_sub->()){
        $self->add_data($data, $outcome, $spec);
    }
    $log->debug( 'Data file: ' . $self->num_exemplars );

    return;
}

# return a sub that returns one data vector per call from the given FH,
# and returns undef once the data file is done being read. Throws errors
# on bad file contents.
sub _read_data_sub {
    my ($self, $data_file) = @_;
    my $data_fh = $data_file->openr_utf8;
    my $column_sep = $self->{field_sep};
    my $variable_separator = $self->{var_sep};
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
        my ($outcome, $data, $spec) = split /$column_sep/, $line, 3;
        # the line has to have at least outcome and data
        if(!defined $data){
            croak "Couldn't read data at line $line_num in $data_file";
        }

        # use data string directly as the default spec string;
        # makes it easier for the user to search their file
        $spec ||= $data;
        my @data_vars = split /$variable_separator/, $data;
        return (\@data_vars, $spec, $outcome);
    };
}

=head2 C<add_data>

Adds the arguments as a new data exemplar. There are four required
arguments: an array ref containing the data variables, the spec, and
the outcome string.

=cut
# $data should be an arrayref of variables
# adds data item to three internal arrays: outcome, data, and spec
sub add_data {
    my ($self, $data, $outcome, $spec) = @_;
    $spec ||= _serialize_data($data);

    $self->_check_variables($data, $spec);
    $self->_update_outcome_vars($outcome);

    # store the new data item
    push @{$self->{spec}}, $spec;
    push @{$self->{data}}, $data;
    push @{$self->{exemplar_outcomes}}, $self->{outcomes}{$outcome};
    return;
}

# check the input variable vector for size, and set the data vector
# size for this project if it isn't set yet
sub _check_variables {
    my ($self, $data, $spec) = @_;
    # check that the number of variables in @$data is correct
    if($self->num_variables != @$data){
        croak 'Expected ' . $self->num_variables .
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

# Sets the testItems to an arrayref of [outcome, [data], spec] for each
# item in the test file (or data file if there is none). outcome is
# the index in outcomelist.
# The test file, like the data file, should have an outcome,
# a data vector, and a spec.
sub _read_test_set {
    my ($self) = @_;
    my $test_file = path($self->base_path, 'test');
    if($test_file->exists){
        my $test_sub = $self->_read_data_sub($test_file);
        while(my ($data, $spec, $outcome) = $test_sub->()){
            $self->add_test($data, $outcome, $spec);
        }
    }else{
        carp "Couldn't open $test_file";
        $log->warn(qq{Couldn't open $test_file; } .
            q{will run data file against itself});
        # we don't need the extra processing of add_test
        @{$self->{testItems}} = map {[
            $self->{exemplar_outcomes}->[$_],
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
    my ($self, $data, $outcome, $spec) = @_;
    # TODO: make sure outcome exists in index

    $self->_check_variables($data, $spec);
    # if it's a new outcome, add it to the list
    if($self->outcome_index($outcome) == -1){
        $self->_update_outcome_vars($outcome);
    }
    push @{$self->{testItems}}, [
        $self->outcome_index($outcome),
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

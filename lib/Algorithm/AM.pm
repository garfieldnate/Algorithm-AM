package Algorithm::AM;
use strict;
use warnings;
# ABSTRACT: Classify data with Analogical Modeling
our $VERSION = '2.45'; # VERSION
use feature 'state';
use Carp;
our @CARP_NOT = qw(Algorithm::AM);
use Class::Tiny qw(
    exclude_nulls
    exclude_given
    linear
), {
    exclude_nulls     => 1,
    exclude_given    => 1,
    linear      => 0,
};

sub BUILD {
    my ($self, $args) = @_;

    if(!exists $args->{training_set}){
        croak "Missing required parameter 'training_set'";
    }
    if('Algorithm::AM::DataSet' ne ref $args->{training_set}){
        croak 'Parameter training_set should ' .
            'be an Algorithm::AM::DataSet';
    }
    $self->_initialize($args->{training_set});
    delete $args->{training_set};
    return;
}

use Algorithm::AM::Result;
use Algorithm::AM::BigInt 'bigcmp';
use Algorithm::AM::DataSet;
use Import::Into;
# Use Import::Into to export classes into caller
sub import {
    my $target = caller;
    Algorithm::AM::BigInt->import::into($target, 'bigcmp');
    Algorithm::AM::DataSet->import::into($target, 'dataset_from_file');
    Algorithm::AM::DataSet::Item->import::into($target, 'new_item');
    return;
}

require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

use Log::Any qw($log);

# do all of the classification data structure initialization here,
# as well as calling the XS initialization method.
sub _initialize {
    my ($self) = @_;

    my $train = $self->training_set;
    # compute activeVars here so that lattice space can be allocated in the
    # _initialize method
    $self->{activeVars} = _compute_lattice_sizes($train->cardinality);

    # sum is intitialized to a list of zeros
    @{$self->{sum}} = (0.0) x ($train->num_classes + 1);

    # preemptively allocate memory
    # TODO: not sure what this does
    @{$self->{itemcontextchain}} = (0) x $train->size;

    $self->{$_} = {} for (
        qw(
            itemcontextchainhead
            context_to_class
            contextsize
            pointers
            gang
        )
    );

    # Initialize XS data structures
    # TODO: Perl crashes unless this is saved. The XS
    # must not be increasing the reference count
    $self->{save_this} = $train->_data_classes;
    $self->_xs_initialize(
        $self->{activeVars},
        $self->{save_this},
        $self->{itemcontextchain},
        $self->{itemcontextchainhead},
        $self->{context_to_class},
        $self->{contextsize},
        $self->{pointers},
        $self->{gang},
        $self->{sum}
    );
    return;
}

sub classify {
    my ($self, $test_item) = @_;

    my $training_set = $self->training_set;
    if($training_set->cardinality != $test_item->cardinality){
        croak 'Training set and test item do not have the same ' .
            'cardinality (' . $training_set->cardinality . ' and ' .
                $test_item->cardinality . ')';
    }

    # num_variables is the number of active variables; if we
    # exclude nulls, then we need to minus the number of '=' found in
    # this test item; otherwise, it's just the number of columns in a
    # single item vector
    my $num_variables = $training_set->cardinality;

    if($self->exclude_nulls){
        $num_variables -= grep {$_ eq ''} @{
            $test_item->features };
    }

    # recalculate the lattice sizes with new number of active variables;
    # must edit activeVars instead of assigning it a new arrayref because
    # the XS code only has the existing arrayref and will not be given
    # a new one. This must be done for every test item because activeVars
    # is a global that could have been edited during classification of the
    # last test item.
    # TODO: pass activeVars into fill_and_count instead of doing this
    {
        my $lattice_sizes = _compute_lattice_sizes($num_variables);
        for(0 .. $#$lattice_sizes){
            $self->{activeVars}->[$_] = $lattice_sizes->[$_];
        }
    }
##  $activeContexts = 1 << $activeVar;

    my $nullcontext = pack "b64", '0' x 64;

    my $given_excluded = 0;
    my $testindata   = 0;

    # initialize classification-related variables
    # it is important to dereference rather than just
    # assigning a new one with [] or {}. This is because
    # the XS code has access to the existing reference,
    # but will be accessing the wrong variable if we
    # change it.
    %{$self->{contextsize}}             = ();
    %{$self->{itemcontextchainhead}}    = ();
    %{$self->{context_to_class}}      = ();
    %{$self->{pointers}}                = ();
    %{$self->{gang}}                    = ();
    @{$self->{itemcontextchain}}        = ();
    # big ints are used in AM.xs; these consist of an
    # array of 8 unsigned longs
    foreach (@{$self->{sum}}) {
        $_ = pack "L!8", 0, 0, 0, 0, 0, 0, 0, 0;
    }

    # calculate context labels and associated structures for
    # the entire data set
    for my $data_index ( 0 .. $training_set->size - 1 ) {
        my $context = _context_label(
            # Note: this must be copied to prevent infinite loop;
            # see todo note for _context_label
            [@{$self->{activeVars}}],
            $training_set->get_item($data_index)->features,
            $test_item->features,
            $self->exclude_nulls
        );
        $self->{contextsize}->{$context}++;
        # TODO: explain itemcontextchain and itemcontextchainhead
        $self->{itemcontextchain}->[$data_index] =
            $self->{itemcontextchainhead}->{$context};
        $self->{itemcontextchainhead}->{$context} = $data_index;

        # store the class for the subcontext; if there
        # is already a different class for this subcontext,
        # then store 0, signifying heterogeneity.
        my $class = $training_set->_index_for_class(
            $training_set->get_item($data_index)->class);
        if ( defined $self->{context_to_class}->{$context} ) {
            $self->{context_to_class}->{$context} = 0
              if $self->{context_to_class}->{$context} != $class;
        }
        else {
            $self->{context_to_class}->{$context} = $class;
        }
    }
    # $nullcontext is all 0's, which is a context label for
    # a data item that exactly matches the test item. Take note
    # of the item, and exclude it if required.
    if ( exists $self->{context_to_class}->{$nullcontext} ) {
        $testindata = 1;
        if($self->exclude_given){
           delete $self->{context_to_class}->{$nullcontext};
           $given_excluded = 1;
        }
    }
    # initialize the results object to hold all of the configuration
    # info.
    my $result = Algorithm::AM::Result->new(
        given_excluded => $given_excluded,
        cardinality => $num_variables,
        exclude_nulls => $self->exclude_nulls,
        count_method => $self->linear ? 'linear' : 'squared',
        training_set => $training_set,
        test_item => $test_item,
        test_in_data => $testindata,
    );

    $log->debug(${$result->config_info})
        if($log->is_debug);

    $result->start_time([ (localtime)[0..2] ]);
    $self->_fillandcount($self->linear ? 0 : 1);
    $result->end_time([ (localtime)[0..2] ]);

    unless ($self->{pointers}->{'grandtotal'}) {
        #TODO: is this tested yet?
        if($log->is_warn){
            $log->warn('No data items considered. ' .
                'No prediction possible.');
        }
        return;
    }

    $result->_process_stats(
        # TODO: after refactoring to a "guts" object,
        # just pass that in
        $self->{sum},
        $self->{pointers},
        $self->{itemcontextchainhead},
        $self->{itemcontextchain},
        $self->{context_to_class},
        $self->{gang},
        $self->{activeVars},
        $self->{contextsize}
    );
    return $result;
}

# since we split the lattice in four, we have to decide which variables
# go where. Given the number of variables being used, return an arrayref
# containing the number of variables to be used in each of the the four
# lattices.
sub _compute_lattice_sizes {
    my ($num_feats) = @_;

    use integer;
    my @active_vars;
    my $half = $num_feats / 2;
    $active_vars[0] = $half / 2;
    $active_vars[1] = $half - $active_vars[0];
    $half         = $num_feats - $half;
    $active_vars[2] = $half / 2;
    $active_vars[3] = $half - $active_vars[2];
    return \@active_vars;
}

# Create binary context labels for a data item
# by comparing it with a test item. Each data item
# needs one binary label for each sublattice (of which
# there are currently four), but this is packed into a
# single scalar representing an array of 4 shorts (this
# format is used in the XS side).

# TODO: we have to copy activeVars out of $self in order to
# iterate it. Otherwise it goes on forever. Why?
sub _context_label {
    # inputs:
    # number of active variables in each lattice,
    # training item features, test item features,
    # and boolean indicating if nulls should be excluded
    my ($active_vars, $train_feats, $test_feats, $skip_nulls) = @_;

    # variable index
    my $index        = 0;
    # the binary context labels for each separate lattice
    my @context_list    = ();

    for my $a (@$active_vars) {
        # binary context label for a single sublattice
        my $context = 0;
        # loop through all variables in the sublattice
        # assign 0 if variables match, 1 if they do not
        for ( ; $a ; --$a ) {

            # skip null variables if indicated
            if($skip_nulls){
                ++$index while $test_feats->[$index] eq '';
            }
            # add a 1 for mismatched variable, 0 for matched variable
            $context = ( $context << 1 ) | (
                $test_feats->[$index] ne $train_feats->[$index] );
            ++$index;
        }
        push @context_list, $context;
    }
    # a context label is an array of unsigned shorts in XS
    my $context = pack "S!4", @context_list;
    return $context;
}

# don't use Class::Tiny for this one because we don't want a
# setter method
sub training_set {
    my ($self) = @_;
    return $self->{training_set};
}

1;
__END__

=head1 SYNOPSIS

 use Algorithm::AM;
 my $dataset = dataset_from_file('finnverb');
 my $am = Algorithm::AM->new(training_set => $dataset);
 my $result = $am->classify($dataset->get_item(0));
 print @{ $result->winners };
 print ${ $result->statistical_summary };

=head1 DESCRIPTION

Analogical Modeling is an exemplar-based way to model language usage.
This module analyzes data sets using Analogical Modeling, an
exemplar-based approach to modeling language usage or other sticky
phenomena. This module logs information using L<Log::Any>, so if you
want automatic print-outs you need to set an adaptor. See the
L</classify> method for more information on logged data.

=head1 EXPORTS

When this module is imported, it also imports the following:

=over

=item L<Algorithm::AM::Result>

=item L<Algorithm::AM::DataSet>

Also imports the L<Algorithm::AM::DataSet/dataset_from_file> function.

=item L<Algorithm::AM::DataSet::Item>

Also imports the L<Algorithm::AM::DataSet::Item/new_item> function.

=item L<Algorithm::AM::BigInt>

Also imports the L<Algorithm::AM::BigInt/bigcmp> function.

=back

=head1 METHODS

=for Pod::Coverage BUILD

=head2 C<new>

Creates a new instance of an analogical modeling classifier. This
method takes named parameters which set set state described in the
documentation for the relevant methods. The only required parameter
is L</training_set>, which should be an instance of
L<Algorithm::AM::DataSet>, and which defines the set of items used
for training during classification. All of the accepted parameters
are listed below:

=over

=item L</training_set>

=item L</exclude_nulls>

=item L</exclude_given>

=item L</linear>

=back

=head2 C<training_set>

Returns (but will not set) the dataset used for training. This is
an instance of L<Algorithm::AM::DataSet>.

=head2 C<exclude_nulls>

Get/set a boolean value indicating whether features with null
values in the test item should be ignored. If false, they will be
treated as having a specific value representing null.
Defaults to true.

=head2 C<exclude_given>

Get/set a boolean value indicating whether the test item should be
removed from the training set if it is found there during
classification. Defaults to true.

=head2 C<linear>

Get/set a boolean value indicating whether the analogical set should
be computed using I<occurrences> (linearly) or I<pointers>
(quadratically). To understand what this means, you should read the
L<algorithm|Algorithm::AM::algorithm> page. A false value indicates
quadratic counting. Defaults to false.

=head2 C<classify>

  $am->classify(new_item(features => ['a','b','c']));

Using the analogical modeling algorithm, this method classifies
the input test item and returns a L<Result|Algorithm::AM::Result>
object.

L<Log::Any> is used for logging. The full classification configuration
is logged at the info level. A notice is printed at the warning
level if no training items can be compared with the test item,
preventing any classification.

=head1 HISTORY

Initially, Analogical Modeling was implemented as a Pascal program.
Subsequently, it was ported to Perl, with substantial improvements
made in 2000. In 2001, the core of the algorithm was rewritten in C,
while the parsing, printing, and statistical routines remained in C;
this was accomplished by embedding a Perl interpreter into the C code.

In 2004, the algorithm was again rewritten, this time in order to
handle more variables and large data sets. The algorithm breaks the
supracontextual lattice into the direct product of four smaller ones,
which the algorithm manipulates individually before recombining.
These lattices can be manipulated in parallel when using the right
hardware, and so the module was named C<AM::Parallel>. This
implementation was written with the core lattice-filling algorithm in
XS, and hooks were provided to help the user create custom reports
and control classification dynamically.

The present version has been renamed to C<Algorithm::AM>, which seemed
a better fit for CPAN. While the XS has largely remained intact, the
Perl code has been completely reorganized and updated to be both more
"modern" and modular. Most of the functionality of C<AM::Parallel>
remains.

=head1 SEE ALSO

The <home page|http://humanities.byu.edu/am/> for Analogical Modeling
includes information about current research and publications, as well as
sample data sets.

The L<Wikipedia article|http://en.wikipedia.org/wiki/Analogical_modeling>
has details and even illustrations on analogical modeling.

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

    $log->info('Reading data file...');
    $self->_read_data_set($data_path);

    $log->info('Reading outcome file...');
    $self->_set_outcomes();

    $log->info('Reading test file...');
    $self->_read_test_set();

    return $self;
}

#read data set, setting internal variables for processing and printing
sub _read_data_set {
    my ($self, $data_path) = @_;

    my @data_set = $data_path->lines;

    $self->{slen} = 0;
    $self->{vlen} = [(0) x 60];
    for (@data_set) {
        # cross-platform chomp
        s/[\n\r]+$// for @data_set;
        my ( $outcome, $data, $spec ) = split /$self->{bigsep}/, $_, 3;
        $spec ||= $data;
        my $l;

        push @{$self->{outcome}}, $outcome;
        push @{$self->{spec}}, $spec;
        $l = length $spec;
        $self->{slen} = $l if $l > $self->{slen};
        my @datavar = split /$self->{smallsep}/, $data;
        push @{$self->{data}}, \@datavar;

        for my $i (0 .. $#datavar ) {
            $l = length $datavar[$i];
            $self->{vlen}->[$i] = $l if $l > $self->{vlen}->[$i];
        }
        $log->debug( 'Data file: ' . scalar(@{$self->{data}}) );
    }
    #length of longest specifier
    $self->{sformat} = "%-$self->{slen}.$self->{slen}s";
    #length of integer holding number of data items
    $self->{dformat} = "%" . ( scalar @{$self->{data}}) . ".0u";
    return;
}

sub _set_outcomes {
    my ($self) = @_;
    $self->{olen} = 0;
    $self->{outcomecounter} = 0;
    $log->info('checking for outcome file');
    my $outcome_path = path($self->{project}, 'outcome');
    if ( $outcome_path->exists ) {
        my @data_set = $outcome_path->lines;
        #cross-platform chomp
        s/[\n\r]+$// for @data_set;
        $self->_read_outcome_set(\@data_set);
    }
    else {
        $log->info('...will use data file');
        $self->_read_outcomes_from_data();
    }
    $log->debug('...converting outcomes to indices');
    @{$self->{outcome}} = map { $self->{octonum}{$_} } @{$self->{outcome}};
    foreach (@{$self->{outcomelist}}) {
        my $l;
        $l = length;
        $self->{olen} = $l if $l > $self->{olen};
    }
    # index 0 is reserved for the AM algorithm
    unshift @{$self->{outcomelist}}, '';
    $self->{oformat} = "%-$self->{olen}.$self->{olen}s";
    return;
}

# outcome file should have one outcome per line, with first a short
# string and then a longer one, separated by a space
#
# sets several key values in $self:
# octonum maps short outcomes to their positions in
# outcomelist, which lists all of the long outcome specs
# outcometonum similarly maps specs
# outcomecounter is the number of unique outcomes
sub _read_outcome_set {
    my ($self, $data_set) = @_;

    # outcomecounter holds number of items processed so far
    # octonum maps short outcomes to the index of their (first)
    #   long version listed in in outcomelist
    # outcometonum maps long outcomes to the same to their own
    #   (first) position in outcomelist
    # outcomelist will hold list of all long outcome strings in file
    for my $datum (@$data_set) {
        my ( $short, $long ) = split /\s+/, $datum, 2;
        $self->{outcomecounter}++;
        $self->{octonum}{$short}   ||= $self->{outcomecounter};
        $self->{outcometonum}{$long} ||= $self->{outcomecounter};
        push @{$self->{outcomelist}}, $long;
    }
    return;
}

# sets several key values in $self:
#
# octonum and outcometonum both map outcome names (from the data file)
# to their positions in outcomelist, which is a sorted list of all of
#   the unique outcomes
# outcomecounter is the number of unique outcomes
sub _read_outcomes_from_data {
    my ($self) = @_;

    # The keys of %oc are the unique outcomes
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

    $self->{outcomecounter} = $counter;

    return;
}

sub _read_test_set {
    my ($self) = @_;
    my $test_file = path($self->{project}, 'test');
    if(!$test_file->exists){
        carp "Couldn't open $self->{project}/test";
        $log->warn('Will run data file against itself');
        $test_file = path($self->{project}, 'data');
    }
    @{$self->{testItems}} = $test_file->lines;
    #cross-platform chomp
    s/[\n\r]+$// for @{ $self->{testItems} };
    return;
}

1;

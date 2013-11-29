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
    $self->{project} = $path;

    $log->info('Reading data file...');
    $self->_read_data_set($data_path);

    $log->info('Reading outcome file...');
    $self->_set_outcomes();

    $log->info('Reading test file...');
    $self->_read_test_set();

    $log->info('...done');

    splice @{$self->{vlen}}, $self->num_features;
    $self->{vformat} = join " ", map { "%-$_.${_}s" } @{$self->{vlen}};

    return $self;
}

sub basepath {
    my ($self) = @_;
    return $self->{project};
}

sub results_path {
    my ($self) = @_;
    return '' . path($self->{project}, 'amcpresults');
}

#returns the number of features in a single data item
sub num_features {
    my ($self, $num) = @_;
    if($num){
        $self->{num_feats} = $num;
    }
    return $self->{num_feats};
}

#read data set, setting internal variables for processing and printing
sub _read_data_set {
    my ($self, $data_path) = @_;

    my @data_set = $data_path->lines;

    # the length of the longest spec
    $self->{slen} = 0;
    # the length of the longest feature of the given column
    $self->{vlen} = [(0) x 60];
    for (@data_set) {
        # cross-platform chomp
        s/[\n\r]+$//;
        my ( $outcome, $data, $spec ) = split /$self->{bigsep}/, $_, 3;

        my @datavar = split /$self->{smallsep}/, $data;
        $self->_add_data($outcome, \@datavar, $spec);

        $log->debug( 'Data file: ' . scalar(@{$self->{data}}) );
    }
    #length of longest specifier
    $self->{sformat} = "%-$self->{slen}.$self->{slen}s";
    #length of integer holding number of data items
    $self->{dformat} = "%" . ( scalar @{$self->{data}}) . ".0u";
    return;
}

#$data should be an arrayref of features
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
    $spec ||= $data;
    push @{$self->{spec}}, $spec;
    push @{$self->{data}}, $data;
    push @{$self->{outcome}}, $outcome;

    #slen holds length of longest spec in data set
    $self->{slen} = do {
        my $l = length $spec;
        $l > $self->{slen} ? $l : $self->{slen};
    };

    # vlen is an arrayref, each index holding the length of the longest feature
    # in that column
    for my $i (0 .. $#$data ) {
        my $l = length $data->[$i];
        $self->{vlen}->[$i] = $l if $l > $self->{vlen}->[$i];
    }
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
        carp "Couldn't open $test_file";
        $log->warn(qq{Couldn't open $test_file; } .
            q{will run data file against itself});
        $test_file = path($self->{project}, 'data');
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

package Analogize;
use strict;
use warnings;
use 5.010;
use Carp;
use Algorithm::AM::Batch;
use Path::Tiny;
# 2.13 needed for aliases
use Getopt::Long 2.13 qw(GetOptionsFromArray);

my $usage = <<'END';
usage: analogize --format [--exemplars] [--project] [--test] [--print] [--help]
  Classify data using analogical modeling
  Required arguments: --format and either --exemplars or --project
  --format: specify either commas or nocommas format for exemplar and
      test data files
  --exemplars: path to the file containing the examplar/training data
  --project: path to AM::Parallel project (ignores 'outcome' file)
  --test: path to the file containing the test data. If none is specified,
      performs leave-one-out classification with the exemplar set
  --print: comma-separated list of reports to print. Available options are:
      config_info, statistical_summary, analogical_set_summary, and
      gang_summary. See documentation in Algorithm::AM::Result for details.
  --help: print this help message
  --?: alias for --help
  --train/data: aliases for --exemplars
END

run(@ARGV) unless caller;

sub run {
    my %args = (
        # defaults here...
    );
    GetOptionsFromArray(\@_, \%args,
        'format=s',
        'exemplars|train|data:s',
        'project:s',
        'test:s',
        'print:s',
        'help|?',
    ) or croak $usage;
    return unless _validate_args(%args);

    my @print_methods;
    if($args{print}){
        @print_methods = split ',', $args{print};
    }

    my ($train, $test);
    if($args{exemplars}){
        $train = dataset_from_file(
            path => $args{exemplars},
            format => $args{format});
    }
    if($args{test}){
        $test = dataset_from_file(
            path => $args{test},
            format => $args{format});
    }
    if($args{project}){
        $train = dataset_from_file(
            path => path($args{project})->child('data'),
            format => $args{format});
        $test = dataset_from_file(
            path => path($args{project})->child('test'),
            format => $args{format});
    }
    # default to leave-one-out if no test set specified
    $test ||= $train;

    my $count = 0;
    my $batch = Algorithm::AM::Batch->new(
        training_set => $train,
        # print the result of each classification as they are provided
        end_test_hook => sub {
            my ($batch, $test_item, $result) = @_;
            ++$count if $result->result eq 'correct';
            say $test_item->comment . ":\t" . $result->result . "\n";
            say ${ $result->$_ } for @print_methods;
        }
    );
    $batch->classify_all($test);

    say "$count out of " . $test->size . " correct";
    return;
}

sub _validate_args {
    my %args = @_;
    if($args{help}){
        say $usage;
        return 0;
    }
    my $errors = '';
    if(!$args{exemplars} and !$args{project}){
        $errors .= "Error: need either --exemplars or --project parameters\n";
    }elsif(($args{exemplars} or $args{test}) and $args{project}){
        $errors .= "Error: --project parameter cannot be used with --exempalrs or --test\n";
    }
    if(!$args{format}){
        $errors .= "Error: missing --format parameter\n";
    }
    if($args{format} !~ m/^(?:no)?commas$/){
        $errors .=
            "Error: --format parameter must be either 'commas' or 'nocommas'\n";
    }
    if($args{print}){
        my %allowed =
            map {$_ => 1} qw(
                config_info
                statistical_summary
                analogical_set_summary
                gang_summary
            );
        for my $param (split ',', $args{print}){
            if(!exists $allowed{$param}){
                $errors .= "Error: unknown print parameter '$param'\n";
            }
        }
    }
    if($errors){
        say $errors . $usage;
        return 0;
    }
    return 1;
}
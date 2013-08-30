use strict;
use warnings;
use Algorithm::AM;
use Test::More 0.88;
plan tests => 4;
use Test::Exception;
use Test::Warn;
use FindBin qw($Bin);
use Path::Tiny;

my $corpus_path = path($Bin, 'data');
my $normal_path = path($corpus_path, 'chapter3');
my $no_data_path = path($corpus_path, 'chapter3_no_data');
my $no_test_path = path($corpus_path, 'chapter3_no_test');
warning_is {
    Algorithm::AM->new(
        $no_test_path,
        commas => 'no',
    );
    } {carped => "Couldn't open $no_test_path/test"},
    'warning for missing test file';

throws_ok {
    Algorithm::AM->new();
    } qr/Must specify project/,
    'dies when no project provided';

throws_ok {
    Algorithm::AM->new(
        $no_data_path,
        commas => 'no',
    );
    } qr/Project has no data file/,
    'dies with missing data file';

throws_ok {
    Algorithm::AM->new(
        $normal_path,
        commas => 'no',
        foo => 'bar'
    );
    } qr/Unknown option foo/,
    'dies with bad argument';
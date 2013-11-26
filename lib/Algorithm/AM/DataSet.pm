package Algorithm::AM::DataSet;
use strict;
use warnings;
# VERSION
# ABSTRACT: store data to be classified by Algorithm::AM

=head1 SYNOPSIS

    use Algorithm::AM;
    use Algorithm::AM::DataSet qw(slurp_data);
    my $data = slurp_data(
        '/path/to/data/file',
        feat_sep => qr//,    #features are single characters
        field_sep => qr/\s+/ #outcome, data, spec separator
    );

    my $p = Algorithm::AM->new(dataset => $data);
    $p->classify();

=head1 DESCRIPTION

This module is used for reading datasets for classifying via
L<Algorithm::AM>. You can specify the format of the data file,
and read separate outcome files.

=head1 EXPORTS

The following method may be exported.

=head2 C<slurp_data>

Reads the data from the given source. The first argument is the
source (filehandle, filename, or string pointer containing actual
data). The other arguments are to specify the format of the input:

=over

=item feat_sep


=item field_sep

=back


=cut
sub slurp_data {
    my ($source, %args) = @_;
}

=head1 TODO

It would be nice to be able to read other kinds of files, e.g.
csv, XML, AIFF, etc.

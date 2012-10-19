use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Dango::Parser;
use Encode;

my $Mode = 'check';

GetOptions(
    '--check' => sub { $Mode = 'check' },
    '--help' => sub { $Mode = 'help' },
) or pod2usage(-verbose => 1);

if ($Mode eq 'check') {
    my $HasError = 0;
    for my $file_name (@ARGV) {
        open my $file, '<', $file_name or die "$0: $file_name: $!";
        local $/ = undef;
        my $parser = Dango::Parser->new;
        my $has_error = 0;
        $parser->onerror(sub {
            my %args = @_;
            warn "$args{message} at line $args{line} ($args{line_data})\n";
            $has_error = 1;
        });
        $parser->parse_char_string(decode 'utf-8', <$file>);
        my $repo = $parser->repository;
        if ($has_error) {
            print "$file_name: Syntax error\n";
            $HasError = 1;
        } else {
            print "$file_name: Syntax ok\n";
        }
    }
    exit $HasError;
} elsif ($Mode eq 'help') {
    pod2usage(-verbose => 2);
} else {
    die "Unknown mode $Mode";
}

=head1 NAME

dango.pl - Dango

=head1 SYNOPSIS

  ./perl bin/dango.pl OPTIONS FILE1 FILE2 ...

=head1 OPTIONS

=over 4

=item --check

Check the syntax of the input files.  Exit with C<1> if some error founds.

=item --help

Show help.

=back


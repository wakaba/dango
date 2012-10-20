use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Dango::Parser;
use Encode;

sub parse_by_file_names ($) {
    my $file_names = shift;

    my $data = '';
    for my $file_name (@$file_names) {
        open my $file, '<', $file_name or die "$0: $file_name: $!";
        local $/ = undef;
        $data .= decode 'utf-8', <$file>;
    }
    my $has_error = 0;
    my $parser = Dango::Parser->new;
    $parser->onerror(sub {
        my %args = @_;
        warn "$args{message} at line $args{line} ($args{line_data})\n";
        $has_error = 1;
    });
    $parser->parse_char_string($data);
    if ($has_error) {
        die "@$file_names: Syntax error\n";
    }
    return $parser->repository;
}

{
    my @command;
    
    GetOptions(
        '--help' => sub { pod2usage(-verbose => 2) },

        map {
            my $v = $_;
            "--$v" => sub { push @command, {type => $v} },
        } qw(print-as-testable),
    ) or pod2usage(-verbose => 1);

    unshift @command, {type => 'parse-files', file_names => [@ARGV]};

    my $repository;

    for my $command (@command) {
        if ($command->{type} eq 'parse-files') {
            $repository = parse_by_file_names $command->{file_names};
        } elsif ($command->{type} eq 'print-as-testable') {
            print $repository->as_testable;
        }
    }
}

=head1 NAME

dango.pl - Dango

=head1 SYNOPSIS

  ./perl bin/dango.pl OPTIONS FILE1 FILE2 ...
  ./perl bin/dango.pl --help

=head1 ARGUMENTS

If one or more non-option arguments are specified, they are
interpreted as file names relative to the current directory.  Those
files are parsed as storage definitions.  If those files contain any
parse error, the script prints error messages to standard error output
and exits the script with status C<1> without executing any command.

There are two kind of options - commands and (proper) options.
Commands specify the actions performed by the script.  Commands are
executed in order; number and order of commands are significant.
Other options control how the script should behave.  Order of other
options are not significant.  Commands and options can be placed in
mixed order.

If no command is specified, the script only parses the specified files
and then exits.  This can be used for syntactical check of the input
files.

There are following commands:

=over 4

=item --print-as-testable

Prints the definitions loaded from the input files in the "testable"
(or canonical) serialization form.

=back

In addition, following options are available:

=over 4

=item --help

Show help.  If this option is specified, any other argument is
ignored.

=back

=head1 AUTHOR

Wakaba <wakabatan@hatena.ne.jp>.

=head1 LICENSE

Copyright 2012 Hatena <http://www.hatena.com/>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

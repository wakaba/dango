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

sub fill_instance_prop ($$) {
    my ($repo, $name) = @_;
    my $has_error;

    $repo->for_each_storage_set(sub {
        my $storage_set = $_;
        my $code = sub {
            my ($obj, $type) = @_;
            next if defined $obj->get_prop($name);
            my $obj_set = $type eq 'db'
                ? $repo->get_db_set($storage_set, $obj->name)
                : do {
                    my $db_set = $repo->get_db_set($storage_set, $obj->db_set_name);
                    $repo->get_table_set($storage_set, $db_set, $obj->name);
                };
            my $template = $obj_set->get_prop($name . '.template');
            if (defined $template) {
                my $set_suffixes = $obj_set->suffixes;
                my $ins_suffixes = $obj->suffixes;
                $template =~ s[\{([^{}]+)\}][
                    my $t = $1;
                    if ($t =~ /^\$([0-9]+)\.([0-9A-Za-z_.-]+)$/) {
                        if (my $ss = $set_suffixes->[$1 - 1]) {
                            my $is = $ins_suffixes->[$1 - 1];
                            if ($ss->{type}) {
                                my $type = $repo->get_table_suffix_type($storage_set, $ss->{type});
                                my $suf = $repo->get_table_suffix($storage_set, $type, $is->{name});
                                my $prop = $suf->get_prop($2);
                                if (defined $prop) {
                                    $prop;
                                } else {
                                    $has_error = 1;
                                    "{NOT DEFINED: \$$1.$2}";
                                }
                            } else {
                                $has_error = 1;
                                "{NOT DEFINED: \$$1.$2}";
                            }
                        } else {
                            $has_error = 1;
                            "{ERROR: \$$1 not found}";
                        }
                    } elsif ($t =~ /^\$([0-9]+)$/) {
                        my $is = $ins_suffixes->[$1 - 1];
                        if ($is->{name}) {
                            $is->{name};
                        } else {
                            $has_error = 1;
                            "{ERROR: \$$1 not found}";
                        }
                    } else {
                        $has_error = 1;
                        "{ERROR: $t}";
                    }
                ]ge;

                $obj->set_prop($name => $template);
            }
        };
        $repo->for_each_db($storage_set, $code, 'db');
        $repo->for_each_table($storage_set, $code, 'table');
    });
    
    return not $has_error;
}

{
    my @command;
    
    GetOptions(
        '--help' => sub { pod2usage(-verbose => 2) },

        (map {
            my $v = $_;
            "--$v" => sub { push @command, {type => $v} },
        } qw(print-as-testable)),
        (map {
            my $v = $_;
            "--$v=s" => sub { push @command, {type => $v, value => $_[1]} },
        } qw(fill-instance-prop)),
    ) or pod2usage(-verbose => 1);

    unshift @command, {type => 'parse-files', file_names => [@ARGV]};

    my $repository;
    my $has_error;
    for my $command (@command) {
        if ($command->{type} eq 'parse-files') {
            $repository = parse_by_file_names $command->{file_names};
        } elsif ($command->{type} eq 'print-as-testable') {
            print $repository->as_testable;
        } elsif ($command->{type} eq 'fill-instance-prop') {
            for (split /,/, $command->{value}) {
                $has_error = not fill_instance_prop $repository, $_;
            }
        }
    }

    if ($has_error) {
        die "Failed\n";
    } else {
        print STDERR "Done\n";
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

=item --fill-instance-prop=PROP1,PROP2,...

Set the instances' property values, if not specified, by classes'
template property values.  For example, if the database set C<A[]> has
property C<hoge.template> with value C<fuga_{$1}> and the database
C<A[4]> has no property C<hoge>, and then the command is executed with
argument C<hoge>, the C<hoge> property of the database C<A[4]> is set
to C<fuga_4> by the command.  If the C<hoge.template> property is not
specified, nothing happens.  Multiple properties can be specified as
comma-separated list.

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
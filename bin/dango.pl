use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Path::Class;
use Dango::Parser;
use Encode;
use Karasuma::Config::JSON;
use JSON::Functions::XS qw(perl2json_bytes_for_record);

sub mkdir_for_file ($) {
    file($_[0])->dir->mkpath;
}

sub write_json ($$) {
    mkdir_for_file $_[1];
    open my $file, '>', $_[1] or die "$0: $_[1]: $!";
    print $file perl2json_bytes_for_record $_[0];
}

sub parse_by_file_name ($$) {
    my ($file_name, $config) = @_;

    open my $file, '<', $file_name or die "$0: $file_name: $!";
    my $data = do {
        local $/ = undef;
        decode 'utf-8', <$file>;
    };
    my $has_error = 0;
    my $parser = Dango::Parser->new;
    $parser->onerror(sub {
        my %args = @_;
        warn "$args{message} at $args{f} line $args{line} ($args{line_data})\n";
        $has_error = 1;
    });
    $parser->config($config);
    $parser->parse_char_string($data, file($file_name));
    die "$file_name has an error\n" if $has_error;
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
                                my $type = $repo->get_suffix_type($storage_set, $ss->{type});
                                my $suf = $repo->get_suffix($storage_set, $type, $is->{name});
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

sub create_tera_storage_json ($) {
    my $repo = shift;

    my $result = {db_set_info => {}};

    $repo->for_each_storage_set(sub {
        my $storage_set = $_[0];
        $repo->for_each_db($storage_set, sub {
            my $db = $_[0];
            push @{$result->{db_set_info}->{$db->name} ||= []}, {
                db => $db->get_prop('name'),
                db_set => $db->name,
                tables => [],
                writable => '',
            };
        });
        $repo->for_each_table($storage_set, sub {
            my $table = $_[0];
            my $table_db = $repo->get_db($storage_set, $table->db_set_name, $table->db_suffixes);
            my $table_db_name = $table_db->get_prop('name');
            my $table_def = {
                table => $table->get_prop('name'),
                table_id => $table->get_prop('table_id'),
                table_stem => $table->get_prop('table_stem'),
                timeline_type => $table->get_prop('timline_type'),
            };
            for (keys %$table_def) {
                delete $table_def->{$_} if not defined $table_def->{$_};
            }
            push @{[grep { $_->{db} eq $table_db_name } @{$result->{db_set_info}->{$table->db_set_name}}]->[0]->{tables} or []}, $table_def;
        });
    });

    for (values %{$result->{db_set_info}}) {
        $_ = [sort { $a->{db} cmp $b->{db} } @$_];
        for (@$_) {
            $_->{tables} = [sort { $a->{table} cmp $b->{table} } @{$_->{tables}}];
        }
    }
    
    return $result;
}

{
    my @command;
    my $config_json_file_name;
    
    GetOptions(
        '--config-json-file-name=s' => \$config_json_file_name,
        '--help' => sub { pod2usage(-verbose => 2) },

        (map {
            my $v = $_;
            "--$v" => sub { push @command, {type => $v} },
        } qw(print-as-testable)),
        (map {
            my $v = $_;
            "--$v=s" => sub { push @command, {type => $v, value => $_[1]} },
        } qw(fill-instance-prop write-tera-storage-json)),
    ) or pod2usage(-verbose => 1);
    pod2usage(-verbose => 1) unless @ARGV == 1;

    unshift @command, {type => 'parse-file', file_name => shift @ARGV};

    my $config;
    if (defined $config_json_file_name) {
        my $f = file($config_json_file_name);
        if (-f $f) {
            $config = Karasuma::Config::JSON->new_from_json_f($f);
        } else {
            die "$0: $f: Not found\n";
        }
    }

    my $repository;
    my $has_error;
    for my $command (@command) {
        if ($command->{type} eq 'parse-file') {
            $repository = parse_by_file_name $command->{file_name}, $config;
        } elsif ($command->{type} eq 'print-as-testable') {
            print $repository->as_testable;
        } elsif ($command->{type} eq 'fill-instance-prop') {
            for (split /,/, $command->{value}) {
                $has_error = not fill_instance_prop $repository, $_;
            }
        } elsif ($command->{type} eq 'write-tera-storage-json') {
            my $json = create_tera_storage_json $repository;
            write_json $json => $command->{value};
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

  ./perl bin/dango.pl OPTIONS FILE
  ./perl bin/dango.pl --help

=head1 ARGUMENTS

If a non-option arguments are specified, it is interpreted as a file
name relative to the current directory.  The file is parsed as storage
definition description.  If the file contains any parse error, the
script prints error messages to standard error output and exits with
status C<1>, without executing any command.

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

=item --write-tera-storage-json=FILE

Generate the storage mapping table data in Tera timeline's
C<storage.json> format.  The generated JSON data is saved in the
specified file name.

=back

In addition, following options are available:

=over 4

=item --config-json-file-name=FILE

Specify the path to the file which contains the JSON data used to
interpret the input storage descrition.  If the input storage
definition contains a reference to the configuration, this option must
be specified.

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

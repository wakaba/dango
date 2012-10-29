use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Path::Class;
use Karasuma::Config::JSON;
use JSON::Functions::XS qw(perl2json_bytes_for_record json_bytes2perl);
use Dango::Process::StorageMaps;

sub mkdir_for_file ($) {
    file($_[0])->dir->mkpath;
}

sub write_text ($$) {
    mkdir_for_file $_[1];
    open my $file, '>', $_[1] or die "$0: $_[1]: $!";
    print $file $_[0];
}

sub write_json ($$) {
    mkdir_for_file $_[1];
    open my $file, '>', $_[1] or die "$0: $_[1]: $!";
    print $file perl2json_bytes_for_record $_[0];
}

sub read_mackerel2_role_json ($) {
    my $f = shift;
    my $json = json_bytes2perl $f->slurp;
    if ($json and ref $json eq 'HASH') {
        return $json;
    } else {
        return undef;
    }
}

{
    my @command;
    my $config_json_file_name;
    my $config_keys_dir_name;
    
    GetOptions(
        '--config-json-file-name=s' => \$config_json_file_name,
        '--config-keys-dir-name=s' => \$config_keys_dir_name,
        '--help' => sub { pod2usage(-verbose => 2) },

        (map {
            my $v = $_;
            "--$v" => sub { push @command, {type => $v} },
        } qw(print-as-testable)),
        (map {
            my $v = $_;
            "--$v=s" => sub { push @command, {type => $v, value => $_[1]} },
        } qw(
            fill-instance-prop write-tera-storage-json
            read-mackerel2-role-json
            write-tera-standalone-mackerel2-role-json
            write-create-database-single-text
            write-preparation-text
            write-dsns-json
        )),
    ) or pod2usage(-verbose => 1);
    pod2usage(-verbose => 1) unless @ARGV == 1;

    unshift @command, {type => 'parse-file', file_name => shift @ARGV};

    my $config;
    if (defined $config_json_file_name) {
        my $f = file($config_json_file_name);
        if (-f $f) {
            $config = Karasuma::Config::JSON->new_from_json_f($f);
            $config->base_d(dir($config_keys_dir_name || '.'));
        } else {
            die "$0: $f: Not found\n";
        }
    }

    my $has_error;
    my $role_json;
    my $process;
    for my $command (@command) {
        if ($command->{type} eq 'parse-file') {
            $process = Dango::Process::StorageMaps->new_from_file_name_and_config($command->{file_name}, $config);
            die "$command->{file_name} has an error\n" if $process->input_has_error;
        } elsif ($command->{type} eq 'print-as-testable') {
            print $process->repository->as_testable;
        } elsif ($command->{type} eq 'fill-instance-prop') {
            for (split /,/, $command->{value}) {
                $has_error = not $process->fill_instance_prop($_);
            }
        } elsif ($command->{type} eq 'write-tera-storage-json') {
            my $json = $process->create_tera_storage_jsonable;
            write_json $json => $command->{value};
        } elsif ($command->{type} eq 'read-mackerel2-role-json') {
            unless (-f $command->{value}) {
                die "File $command->{value} not found";
            } else {
                $role_json = read_mackerel2_role_json file($command->{value});
            }
        } elsif ($command->{type} eq 'write-tera-standalone-mackerel2-role-json') {
            my $json = $process->create_mackerel2_role_jsonable_for_tera_standalone;
            write_json $json => $command->{value};
        } elsif ($command->{type} eq 'write-create-database-single-text') {
            my $text = $process->create_create_database_standalone_list;
            write_text $text => $command->{value};
        } elsif ($command->{type} eq 'write-preparation-text') {
            my $text = $process->create_preparation_text;
            write_text $text => $command->{value};
        } elsif ($command->{type} eq 'write-dsns-json') {
            my $json = $process->create_dsns_jsonable($role_json);
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

=item --write-tera-standalone-mackerel2-role-json=FILE

Generate the storage role - hostname/port mapping data in Mackerel2
format, from Tera timeline's standalone server configuration file
(specified by C<--config-json-file-name>).

=item --write-create-database-single-text=FILE

Generate the list of SQL C<CREATE DATABASE> statements for databases
in the storage description.

=item --write-preparation-text=FILE

Generate the database preparation (C<CREATE DATABASE>) configuration
file in the C<preparation.txt> format as supported by
C<prepare-db-set.pl>.  See
<https://github.com/wakaba/perl-rdb-utils/blob/master/bin/prepare-db-set.pl>
for more information.

=item --read-mackerel2-role-json=FILE

Read the specified file as storage role - hostname/port mapping data
in Mackerel2 format.  The data is used to generate C<dsns.json>.

=item --write-dsns-json=FILE

Generate the C<dsns.json> file
<https://github.com/wakaba/perl-rdb-utils/wiki/dsns.json> from the
storage description.

=back

In addition, following options are available:

=over 4

=item --config-json-file-name=FILE

Specify the path to the file which contains the JSON data used to
interpret the input storage descrition.  If the input storage
definition contains a reference to the configuration, this option must
be specified.

=item --config-keys-dir-name=DIR

Specify the path to the directory which contains keys referenced by
JSON data specified by the C<--config-json-file-name> option.  For
more information, see L<Karasuma::Config::JSON>.

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

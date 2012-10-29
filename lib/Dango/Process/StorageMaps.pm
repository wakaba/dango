package Dango::Process::StorageMaps;
use strict;
use warnings;
use Encode;
use Path::Class;
use Dango::Parser;

sub new_from_repository_and_config {
    return bless {repository => $_[1], config => $_[2]}, $_[0];
}

sub new_from_file_name_and_config {
    my ($class, $file_name, $config) = @_;

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
    my $self = $class->new_from_repository_and_config($parser->repository, $config);
    $self->{input_has_error} = $has_error;
    return $self;
}

sub input_has_error {
    return $_[0]->{input_has_error};
}

sub repository {
    return $_[0]->{repository};
}

sub config {
    return $_[0]->{config};
}

sub fill_instance_prop {
    my ($self, $name) = @_;
    my $repo = $self->repository;
    my $config = $self->config;
    my $has_error;

    $repo->for_each_storage_set(sub {
        my $storage_set = $_;
        my $code = sub {
            my ($obj, $type) = @_;
            return if defined $obj->get_prop($name);
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
                    } elsif ($t =~ /^--([0-9A-Za-z_.-]+)$/) {
                        if ($config) {
                            my $value = $config->get_text($1);
                            if (defined $value) {
                                $value;
                            } else {
                                "{ERROR: $1 not defined}";
                            }
                        } else {
                            $has_error = 1;
                            "{ERROR: No config}";
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

sub create_tera_storage_jsonable {
    my $self = shift;
    my $repo = $self->repository;

    my $result = {db_set_info => {}, dc_id => {}};

    $repo->for_each_storage_set(sub {
        my $storage_set = $_[0];
        $repo->for_each_db($storage_set, sub {
            my $db = $_[0];
            my $db_def = {
                db => $db->get_prop('name'),
                db_set => $db->name,
                tables => [],
                writable => $db->get_prop('writable'),
                master_only => $db->get_prop('master_only'),
            };
            for (keys %$db_def) {
                delete $db_def->{$_} if not defined $db_def->{$_};
            }
            push @{$result->{db_set_info}->{$db->name} ||= []}, $db_def;
        });
        $repo->for_each_table($storage_set, sub {
            my $table = $_[0];
            my $table_db = $repo->get_db($storage_set, $table->db_set_name, $table->db_suffixes);
            my $table_db_name = $table_db->get_prop('name');
            my $table_def = {
                table => $table->get_prop('name'),
                table_id => $table->get_prop('table_id'),
                table_stem => $table->get_prop('table_stem'),
                table_name_stem => $table->get_prop('table_name_stem'),
                timeline_type => $table->get_prop('timeline_type'),
                enabled => $table->get_prop('enabled'),
                for_admin => $table->get_prop('for_admin'),
            };
            for (keys %$table_def) {
                delete $table_def->{$_} if not defined $table_def->{$_};
            }
            for (qw(enabled for_admin)) {
                delete $table_def->{$_} unless $table_def->{$_};
            }
            push @{[grep { $_->{db} eq $table_db_name } @{$result->{db_set_info}->{$table->db_set_name}}]->[0]->{tables} or []}, $table_def;
        });

        for (keys %{$storage_set->get_prop('dc_id') or {}}) {
            $result->{dc_id}->{$_} = $storage_set->get_prop('dc_id.' . $_);
        }

        my $db_name = $storage_set->get_prop('id_db.db');
        if (defined $db_name) {
            my @db;
            $repo->for_each_db($storage_set, sub {
                my $db = $_;
                if ($db->name eq $db_name and $db->get_prop('writable')) {
                    push @db, $db;
                }
            });
            my $db = [sort { (join $;, map { $_->{name} } @{$a->suffixes}) cmp (join $;, map { $_->{name} } @{$b->suffixes}) } @db]->[0];
            if ($db) {
                $result->{id_db} = $db->get_prop('name');
            }
        }
    });

    for (values %{$result->{db_set_info}}) {
        $_ = [sort { $a->{db} cmp $b->{db} } @$_];
        for (@$_) {
            $_->{tables} = [sort { $a->{table} cmp $b->{table} } @{$_->{tables}}];
        }
    }
    
    return $result;
}

sub create_mackerel2_role_jsonable_for_tera_standalone {
    my $self = shift;
    my $repo = $self->repository;
    my $config = $self->config;

    my $host = $config->get_text('tera.standalone.database.host');
    my $port = $config->get_text('tera.standalone.database.port');
    $host = 'localhost' unless defined $host;
    $host .= ':' . $port if $port;

    my $result = {};
    
    $repo->for_each_storage_set(sub {
        my $storage_set = $_[0];
        $repo->for_each_storage_role(sub {
            my $role = $_[0];
            $result->{$role->name . '-master'} = $host;
            for (keys %{$role->get_prop('slave_sets') or {}}) {
                $result->{$role->name . '-slave-' . $_} = $host;
            }
        });
    });

    return $result;
}

sub create_create_database_standalone_list {
    my $self = shift;
    my $repo = $self->repository;

    my $result = [];

    $repo->for_each_storage_set(sub {
        my $storage_set = $_[0];
        $repo->for_each_db($storage_set, sub {
            my $db = $_[0];
            push @$result, 'CREATE DATABASE IF NOT EXISTS `' . $db->get_prop('name') . '`;';
        });
    });

    return join "\n", sort { $a cmp $b } @$result;
}

sub create_preparation_text {
    my $self = shift;
    my $repo = $self->repository;

    my $result = [];

    $repo->for_each_storage_set(sub {
        my $storage_set = $_[0];
        $repo->for_each_db($storage_set, sub {
            my $db = $_[0];
            push @$result, 'db ' . $db->get_prop('name');
        });
    });

    return join "\n", sort { $a cmp $b } @$result;
}

sub _dsn {
    my ($self, $role, $db, $role_jsonable, $set) = @_;
    my $config = $self->config;
    my ($hostname, $port) = split /:/, $role_jsonable->{$role->name . '-' . $set}, 2;
    my $user = $config->get_file_base64_text('dango.database.user');
    my $pass = $config->get_file_base64_text('dango.database.password');
    die "dango.database.user not defined in config json\n" unless defined $user;
    die "dango.database.password not defined in config json\n" unless defined $pass;
    return sprintf 'DBI:mysql:dbname=%s;host=%s%s;user=%s;password=%s',
        $db->get_prop('name'),
        $hostname, ($port ? ';port=' . $port : ''),
        $user,
        $pass;
}

sub create_dsns_jsonable {
    my ($self, $role_jsonable) = @_;
    my $repo = $self->repository;
    my $config = $self->config;

    # <https://github.com/wakaba/perl-rdb-utils/wiki/dsns.json>

    my $result = {dsns => {}};

    $repo->for_each_storage_set(sub {
        my $storage_set = $_[0];
        my $slave_type = $storage_set->get_prop('current_slave_set');
        $repo->for_each_db($storage_set, sub {
            my $db = $_[0];
            my $role = $repo->get_storage_role($db->storage_role_name);
            my $name = $db->get_prop('key') || $db->get_prop('name');
            if (defined $slave_type and
                ($role->get_prop('slave_sets') or {})->{$slave_type}) {
                $result->{dsns}->{$name} = $self->_dsn($role, $db, $role_jsonable, 'slave-' . $slave_type);
                $result->{alt_dsns}->{master}->{$name} = $self->_dsn($role, $db, $role_jsonable, 'master');
            } else {
                $result->{dsns}->{$name} = $self->_dsn($role, $db, $role_jsonable, 'master');
            }
        });
    });

    return $result;
}

1;

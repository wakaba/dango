package Dango::Parser;
use strict;
use warnings;
use Path::Class;
use Encode;
use Dango::Repository;
use Dango::Object::StorageRole;
use Dango::Object::ApplicationRole;
use Dango::Object::StorageSet;
use Dango::Object::DatabaseSet;
use Dango::Object::TableSet;
use Dango::Object::SuffixType;
use Dango::Object::Suffix;
use Dango::Object::Database;
use Dango::Object::Table;

sub new {
    return bless {}, $_[0];
}

sub repository {
    return $_[0]->{repository} ||= Dango::Repository->new;
}

sub config {
    if (@_ > 1) {
        $_[0]->{config} = $_[1];
    }
    return $_[0]->{config};
}

sub onerror {
    if (@_ > 1) {
        $_[0]->{onerror} = $_[1];
    }
    return $_[0]->{onerror} || sub { my %args = @_; warn "$args{message} at @{[$args{f} ? $args{f} . ' ' : '']}line $args{line} ($args{line_data})\n" };
}

sub parse_char_string {
    my ($self, $s, $input_f) = @_;
    my $base_d = $input_f ? $input_f->dir->resolve : dir('.')->resolve;
    my $line_number = 0;
    my $has_error;
    my $last_obj;
    my $repo = $self->repository;
    for my $line (split /\x0D?\x0A/, $s) {
        $line_number++;
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        next if $line =~ /^$/;
        next if $line =~ /^#/;

        if ($line =~ /^include\s+(.+)$/) {
            my $f = file($1)->absolute($base_d);
            if (-f $f) {
                $self->parse_char_string((decode 'utf-8', scalar $f->slurp), $f);
            } else {
                $self->onerror->(
                    message => "File $1 not found",
                    f => $input_f,
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }

        # Storage set

        } elsif ($line =~ /^storage_set\s+([0-9A-Za-z_-]+)$/) {
            my $obj = Dango::Object::StorageSet->new_from_name($1);
            if ($repo->has_object($obj)) {
                $self->onerror->(
                    message => "Duplicate definition",
                    f => $input_f,
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            $repo->add_object($obj);
            $last_obj = $self->{storage_set} = $obj;

        # Set definitions

        } elsif ($line =~ /^(db_set|suffix_type)\s+([0-9A-Za-z_-]+)((?:\[[0-9A-Za-z_-]*\])*)$/) {
            unless ($self->{storage_set}) {
                $self->onerror->(
                    message => "Storage set is not defined yet",
                    f => $input_f,
                    line  => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            my $cls = {
                db_set => 'Dango::Object::DatabaseSet',
                suffix_type => 'Dango::Object::SuffixType',
            }->{$1};
            my $obj = $cls->new_from_storage_set_and_name($self->{storage_set}, $2);
            if ($repo->has_object($obj)) {
                $self->onerror->(
                    message => "Duplicate definition",
                    f => $input_f,
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            my $suffixes = $self->parse_suffix_definition($3, $input_f, $line_number, $line);
            unless ($suffixes) {
                $has_error = 1;
                next;
            }
            $obj->suffixes($suffixes);
            $repo->add_object($obj);
            $last_obj = $obj;
        } elsif ($line =~ /^(table_set|suffix)\s+([0-9A-Za-z_-]+)\.([0-9A-Za-z_-]+)((?:\[[0-9A-Za-z_-]*\])*)$/) {
            unless ($self->{storage_set}) {
                $self->onerror->(
                    message => "Storage set is not defined yet",
                    f => $input_f,
                    line  => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            my $def = {
                table_set => {
                    get_parent => 'get_db_set',
                    class => 'Dango::Object::TableSet',
                    constructor => 'new_from_storage_set_and_db_set_and_name',
                    allow_suffixes => 1,
                },
                suffix => {
                    get_parent => 'get_suffix_type',
                    class => 'Dango::Object::Suffix',
                    constructor => 'new_from_storage_set_and_suffix_type_and_name',
                    allow_suffixes => 0,
                },
            }->{$1};
            my $parent = $repo->can($def->{get_parent})->($repo, $self->{storage_set}, $2);
            unless ($parent) {
                $self->onerror->(
                    message => "Object $2 not defined",
                    f => $input_f,
                    line  => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            my $obj = $def->{class}->can($def->{constructor})->($def->{class}, $self->{storage_set}, $parent, $3);
            if ($repo->has_object($obj)) {
                $self->onerror->(
                    message => "Duplicate definition",
                    f => $input_f,
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            if ($def->{allow_suffixes}) {
                my $suffixes = $self->parse_suffix_definition($4, $input_f, $line_number, $line);
                unless ($suffixes) {
                    $has_error = 1;
                    next;
                }
                $obj->suffixes($suffixes);
            } elsif ($4) {
                $self->onerror->(
                    message => 'Syntax error',
                    f => $input_f,
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            $repo->add_object($obj);
            $last_obj = $obj;

        # Roles

        } elsif ($line =~ /^(storage_role|app_role)\s*(\S+)$/) {
            my $def = {
                storage_role => {
                    class => 'Dango::Object::StorageRole',
                },
                app_role => {
                    class => 'Dango::Object::ApplicationRole',
                },
            }->{$1};
            my $obj = $def->{class}->new_from_name($2);
            if ($repo->has_object($obj)) {
                $self->onerror->(
                    message => "Duplicate definition",
                    f => $input_f,
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            $repo->add_object($obj);
            $last_obj = $obj;

        # Instances

        } elsif ($line =~ /^(db)\s*([0-9A-Za-z_-]+)\.([0-9A-Za-z_-]+)((?:\[[0-9A-Za-z_-]*\])*)$/) {
            unless ($self->{storage_set}) {
                $self->onerror->(
                    message => "Storage set is not defined yet",
                    f => $input_f,
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            my $role = $repo->get_storage_role($2);
            unless ($role) {
                $self->onerror->(
                    message => "Storage role $2 not defined",
                    f => $input_f,
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            my $db_set = $repo->get_db_set($self->{storage_set}, $3);
            unless ($db_set) {
                $self->onerror->(
                    message => "Database set $3 not defined",
                    f => $input_f,
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            my $suffixes = $self->parse_suffix_instance($db_set, $4, $input_f, $line_number, $line);
            unless ($suffixes) {
                $has_error = 1;
                next;
            }
            my $obj = Dango::Object::Database->new_from_storage_set_and_storage_role_and_db_set($self->{storage_set}, $role, $db_set);
            $obj->suffixes($suffixes);
            if ($repo->has_object($obj)) {
                $self->onerror->(
                    message => "Duplicate definition",
                    f => $input_f,
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            $repo->add_object($obj);
            $last_obj = $obj;
        } elsif ($line =~ /^(table)\s*([0-9A-Za-z_-]+)((?:\[[0-9A-Za-z_-]*\])*)\.([0-9A-Za-z_-]+)((?:\[[0-9A-Za-z_-]*\])*)$/) {
            unless ($self->{storage_set}) {
                $self->onerror->(
                    message => "Storage set is not defined yet",
                    f => $input_f,
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            my $db_set = $repo->get_db_set($self->{storage_set}, $2);
            unless ($db_set) {
                $self->onerror->(
                    message => "Database set $2 not defined",
                    f => $input_f,
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            my $db_suffixes = $self->parse_suffix_instance($db_set, $3, $input_f, $line_number, $line);
            my $db = $repo->get_db($self->{storage_set}, $2, $db_suffixes);
            unless ($db) {
                $self->onerror->(
                    message => "Database $2$3 not defined",
                    f => $input_f,
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            my $table_set = $repo->get_table_set($self->{storage_set}, $db_set, $4);
            unless ($table_set) {
                $self->onerror->(
                    message => "Table set $4 not defined",
                    f => $input_f,
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            my $suffixes = $self->parse_suffix_instance($table_set, $5, $input_f, $line_number, $line);
            unless ($suffixes) {
                $has_error = 1;
                next;
            }
            my $obj = Dango::Object::Table->new_from_storage_set_and_db_and_table_set($self->{storage_set}, $db, $table_set);
            $obj->suffixes($suffixes);
            if ($repo->has_object($obj)) {
                $self->onerror->(
                    message => "Duplicate definition",
                    f => $input_f,
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            $repo->add_object($obj);
            $last_obj = $obj;

        # Properties

        } elsif ($line =~ /^\.([0-9A-Za-z_-]+(?:\.[0-9A-Za-z_-]+)*)\s*(=|<-|--)\s*(.*)$/) {
            unless ($last_obj) {
                $self->onerror->(
                    message => "Target object is not defined yet",
                    f => $input_f,
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            if ($last_obj->has_prop($1)) {
                $self->onerror->(
                    message => "Property $1 is already specified",
                    f => $input_f,
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            my ($n, $op, $v) = ($1, $2, $3);
            $v =~ s/\A\s+//;
            $v =~ s/\s+\z//;
            if ($op eq '=') {
                $last_obj->set_prop($n => $v);
            } elsif ($op eq '<-') {
                $last_obj->set_prop($n => {map { $_ => 1 } split /\s*,\s*/, $v});
            } elsif ($op eq '--') {
                my $config = $self->config;
                unless ($config) {
                    $self->onerror->(
                        message => "Config object is not set",
                        f => $input_f,
                        line => $line_number, line_data => $line,
                    );
                    $has_error = 1;
                    next;
                }
                my $value = $config->get_text($v);
                if (not defined $value) {
                    $self->onerror->(
                        message => "Config $v is not defined",
                        f => $input_f,
                        line => $line_number, line_data => $line,
                    );
                    $has_error = 1;
                    next;
                }
                $last_obj->set_prop($n => $value);
            }

        } else {
            $self->onerror->(
                message => "Syntax error",
                f => $input_f,
                line => $line_number, line_data => $line,
            );
            $has_error = 1;
        }
    }
    return not $has_error;
}

sub parse_suffix_definition {
    my ($self, $text, $input_f, $line_number, $line) = @_;
    my $repo = $self->repository;
    my $suffixes = [];
    while ($text =~ s/^\[([0-9A-Za-z_-]*)\]//) {
        if (length $1) {
            my $suffix_type = $repo->get_suffix_type($self->{storage_set}, $1);
            unless ($suffix_type) {
                $self->onerror->(
                    message => "Table suffix type $1 not defined",
                    f => $input_f,
                    line => $line_number, line_data => $line,
                );
                return undef;
            }
        }
        push @$suffixes, length $1 ? {type => $1} : {};
    }
    return $suffixes;
}

sub parse_suffix_instance {
    my ($self, $class_obj, $text, $input_f, $line_number, $line) = @_;
    my $repo = $self->repository;
    my $suffixes = [];
    my $class_suffixes = $class_obj->suffixes;
    my $i = 0;
    while ($text =~ s/^\[([0-9A-Za-z_-]*)\]//) {
        my $s = $class_suffixes->[$i];
        if ($s) {
            if (defined $s->{type}) {
                my $suffix_type = $repo->get_suffix_type($self->{storage_set}, $s->{type});
                my $suffix = $repo->get_suffix($self->{storage_set}, $suffix_type, $1);
                unless ($suffix) {
                    $self->onerror->(
                        message => "Table suffix $1 not defined",
                        f => $input_f,
                        line => $line_number, line_data => $line,
                    );
                    return undef;
                }
                push @$suffixes, {name => $1};
            } else {
                my $value = $1;
                if ($value =~ /\A[0-9]+\z/) {
                    push @$suffixes, {name => $value};
                } else {
                    $self->onerror->(
                        message => "Table suffix $1 is not an integer",
                        f => $input_f,
                        line => $line_number, line_data => $line,
                    );
                    return undef;
                }
            }
        } else {
            $self->onerror->(
                message => 'Too many suffix specifications',
                f => $input_f,
                line => $line_number, line_data => $line,
            );
            return undef;
        }
        $i++;
    }
    return $suffixes;
}

1;


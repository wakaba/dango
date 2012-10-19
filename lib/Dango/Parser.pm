package Dango::Parser;
use strict;
use warnings;
use Dango::Repository;
use Dango::Object::StorageRole;
use Dango::Object::ApplicationRole;
use Dango::Object::StorageSet;
use Dango::Object::DatabaseSet;
use Dango::Object::TableSet;
use Dango::Object::TableSuffixType;
use Dango::Object::TableSuffix;
use Dango::Object::Database;

sub new {
    return bless {}, $_[0];
}

sub repository {
    return $_[0]->{repository} ||= Dango::Repository->new;
}

sub onerror {
    if (@_ > 1) {
        $_[0]->{onerror} = $_[1];
    }
    return $_[0]->{onerror} || sub { my %args = @_; warn "$args{message} at line $args{line} ($args{line_data})\n" };
}

sub parse_char_string {
    my $self = shift;
    my $line_number = 0;
    my $has_error;
    my $storage_set;
    my $last_obj;
    my $repo = $self->repository;
    for my $line (split /\x0D?\x0A/, $_[0]) {
        $line_number++;
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        next if $line =~ /^$/;
        next if $line =~ /^#/;

        # Storage set

        if ($line =~ /^storage_set\s+([0-9A-Za-z_-]+)$/) {
            my $obj = Dango::Object::StorageSet->new_from_name($1);
            if ($repo->has_object($obj)) {
                $self->onerror->(
                    message => "Duplicate definition",
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            $repo->add_object($obj);
            $last_obj = $storage_set = $obj;

        # Set definitions

        } elsif ($line =~ /^(db_set|table_suffix_type)\s+([0-9A-Za-z_-]+)((?:\[[0-9A-Za-z_-]*\])*)$/) {
            unless ($storage_set) {
                $self->onerror->(
                    message => "Storage set is not defined yet",
                    line  => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            my $cls = {
                db_set => 'Dango::Object::DatabaseSet',
                table_suffix_type => 'Dango::Object::TableSuffixType',
            }->{$1};
            my $obj = $cls->new_from_storage_set_and_name($storage_set, $2);
            if ($repo->has_object($obj)) {
                $self->onerror->(
                    message => "Duplicate definition",
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            my $suffixes = $self->parse_suffix_definition($storage_set, $3, $line_number, $line);
            unless ($suffixes) {
                $has_error = 1;
                next;
            }
            $obj->suffixes($suffixes);
            $repo->add_object($obj);
            $last_obj = $obj;
        } elsif ($line =~ /^(table_set|table_suffix)\s+([0-9A-Za-z_-]+)\.([0-9A-Za-z_-]+)((?:\[[0-9A-Za-z_-]*\])*)$/) {
            unless ($storage_set) {
                $self->onerror->(
                    message => "Storage set is not defined yet",
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
                table_suffix => {
                    get_parent => 'get_table_suffix_type',
                    class => 'Dango::Object::TableSuffix',
                    constructor => 'new_from_storage_set_and_table_suffix_type_and_name',
                    allow_suffixes => 0,
                },
            }->{$1};
            my $parent = $repo->can($def->{get_parent})->($repo, $storage_set, $2);
            unless ($parent) {
                $self->onerror->(
                    message => "Object $2 not defined",
                    line  => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            my $obj = $def->{class}->can($def->{constructor})->($def->{class}, $storage_set, $parent, $3);
            if ($repo->has_object($obj)) {
                $self->onerror->(
                    message => "Duplicate definition",
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            if ($def->{allow_suffixes}) {
                my $suffixes = $self->parse_suffix_definition($storage_set, $4, $line_number, $line);
                unless ($suffixes) {
                    $has_error = 1;
                    next;
                }
                $obj->suffixes($suffixes);
            } elsif ($4) {
                $self->onerror->(
                    message => 'Syntax error',
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
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            $repo->add_object($obj);
            $last_obj = $obj;

        # Instances

        } elsif ($line =~ /^(db)\s*([0-9A-Za-z_-]+)\.([0-9A-Za-z_-]+)((?:\[[0-9A-Za-z_-]*\])*)$/) {
            unless ($storage_set) {
                $self->onerror->(
                    message => "Storage set is not defined yet",
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            my $role = $repo->get_storage_role($2);
            unless ($role) {
                $self->onerror->(
                    message => "Storage role $2 not defined",
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            my $db_set = $repo->get_db_set($storage_set, $3);
            unless ($db_set) {
                $self->onerror->(
                    message => "Database set $3 not defined",
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            my $suffixes = $self->parse_suffix_instance($storage_set, $db_set, $4, $line_number, $line);
            unless ($suffixes) {
                $has_error = 1;
                next;
            }
            my $obj = Dango::Object::Database->new_from_storage_set_and_storage_role_and_db_set($storage_set, $role, $db_set);
            $obj->suffixes($suffixes);
            if ($repo->has_object($obj)) {
                $self->onerror->(
                    message => "Duplicate definition",
                    line => $line_number, line_data => $line,
                );
                $has_error = 1;
                next;
            }
            $repo->add_object($obj);
            $last_obj = $obj;

        } else {
            $self->onerror->(
                message => "Syntax error",
                line => $line_number, line_data => $line,
            );
            $has_error = 1;
        }
    }
    return not $has_error;
}

sub parse_suffix_definition {
    my ($self, $storage_set, $text, $line_number, $line) = @_;
    my $repo = $self->repository;
    my $suffixes = [];
    while ($text =~ s/^\[([0-9A-Za-z_-]*)\]//) {
        if (length $1) {
            my $table_suffix_type = $repo->get_table_suffix_type($storage_set, $1);
            unless ($table_suffix_type) {
                $self->onerror->(
                    message => "Table suffix type $1 not defined",
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
    my ($self, $storage_set, $class_obj, $text, $line_number, $line) = @_;
    my $repo = $self->repository;
    my $suffixes = [];
    my $class_suffixes = $class_obj->suffixes;
    my $i = 0;
    while ($text =~ s/^\[([0-9A-Za-z_-]*)\]//) {
        my $s = $class_suffixes->[$i];
        if ($s) {
            if (defined $s->{type}) {
                my $table_suffix_type = $repo->get_table_suffix_type($storage_set, $s->{type});
                my $table_suffix = $repo->get_table_suffix($storage_set, $table_suffix_type, $1);
                unless ($table_suffix) {
                    $self->onerror->(
                        message => "Table suffix $1 not defined",
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
                        line => $line_number, line_data => $line,
                    );
                    return undef;
                }
            }
        } else {
            $self->onerror->(
                message => 'Too many suffix specifications',
                line => $line_number, line_data => $line,
            );
            return undef;
        }
        $i++;
    }
    return $suffixes;
}

1;


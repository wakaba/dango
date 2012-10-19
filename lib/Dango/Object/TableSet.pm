package Dango::Object::TableSet;
use strict;
use warnings;
use Dango::Object::Base;
push our @ISA, qw(Dango::Object::Base);

sub new_from_storage_set_and_db_set_and_name {
    return bless {
        storage_set_name => $_[1]->name,
        db_set_name => $_[2]->name,
        name => $_[3],
    }, $_[0];
}

sub type {
    return 'table_set';
}

sub db_set_name {
    return $_[0]->{db_set_name}; # or undef
}

sub parent_name {
    return $_[0]->db_set_name;
}

sub _as_testable {
    return sprintf 'table_set %s.%s%s',
        $_[0]->db_set_name, $_[0]->name,
        join '', map { defined $_->{type} ? "[$_->{type}]" : "[]" } @{$_[0]->suffixes};
}

1;

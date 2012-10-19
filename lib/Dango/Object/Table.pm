package Dango::Object::Table;
use strict;
use warnings;
use Dango::Object::Base;
push our @ISA, qw(Dango::Object::Base);

sub new_from_storage_set_and_db_and_table_set {
    return bless {
        storage_set_name => $_[1]->name,
        db_set_name => $_[2]->name,
        db_suffixes => $_[2]->suffixes,
        name => $_[3]->name,
    }, $_[0];
}

sub type {
    return 'table';
}

sub db_set_name {
    return $_[0]->{db_set_name};
}

sub db_suffixes {
    return $_[0]->{db_suffixes};
}

sub _as_testable {
    return sprintf 'table %s%s.%s%s',
        $_[0]->db_set_name,
        (join '', map { "[$_->{name}]" } @{$_[0]->db_suffixes}),
        $_[0]->name,
        join '', map { "[$_->{name}]" } @{$_[0]->suffixes};
}

1;

package Dango::Object::Database;
use strict;
use warnings;
use Dango::Object::Base;
push our @ISA, qw(Dango::Object::Base);

sub new_from_storage_set_and_storage_role_and_db_set {
    return bless {
        storage_set_name => $_[1]->name,
        storage_role_name => $_[2]->name,
        name => $_[3]->name,
    }, $_[0];
}

sub type {
    return 'db';
}

sub storage_role_name {
    return $_[0]->{storage_role_name};
}

sub as_testable {
    return sprintf 'db %s.%s%s',
        $_[0]->storage_role_name,
        $_[0]->name,
        join '', map { "[$_->{name}]" } @{$_[0]->suffixes};
}

1;

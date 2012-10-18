package Dango::Object::DatabaseSet;
use strict;
use warnings;
use Dango::Object::Base;
push our @ISA, qw(Dango::Object::Base);

sub new_from_storage_set_and_name {
    return bless {storage_set_name => $_[1]->name, name => $_[2]}, $_[0];
}

sub type {
    return 'db_set';
}

sub as_testable {
    return sprintf 'db_set %s%s',
        $_[0]->name,
        join '', map { defined $_->{type} ? "[$_->{type}]" : "[]" } @{$_[0]->suffixes};
}

1;

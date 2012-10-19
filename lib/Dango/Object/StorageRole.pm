package Dango::Object::StorageRole;
use strict;
use warnings;
use Dango::Object::Base;
push our @ISA, qw(Dango::Object::Base);

sub new_from_name {
    return bless {name => $_[1]}, $_[0];
}

sub type {
    return 'storage_role';
}

sub as_testable {
    return sprintf 'storage_role %s',
        $_[0]->name;
}

1;

package Dango::Object::TableSuffixType;
use strict;
use warnings;
use Dango::Object::Base;
push our @ISA, qw(Dango::Object::Base);

sub new_from_storage_set_and_name {
    return bless {storage_set_name => $_[1]->name, name => $_[2]}, $_[0];
}

sub type {
    return 'table_suffix_type';
}

sub _as_testable {
    return sprintf 'table_suffix_type %s',
        $_[0]->name;
}

1;

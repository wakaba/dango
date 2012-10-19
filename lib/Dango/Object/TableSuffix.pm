package Dango::Object::TableSuffix;
use strict;
use warnings;
use Dango::Object::Base;
push our @ISA, qw(Dango::Object::Base);

sub new_from_storage_set_and_table_suffix_type_and_name {
    return bless {
        storage_set_name => $_[1]->name,
        table_suffix_type_name => $_[2]->name,
        name => $_[3],
    }, $_[0];
}

sub type {
    return 'table_suffix';
}

sub table_suffix_type_name {
    return $_[0]->{table_suffix_type_name}; # or undef
}

sub parent_name {
    return $_[0]->table_suffix_type_name;
}

sub _as_testable {
    return sprintf 'table_suffix %s.%s',
        $_[0]->table_suffix_type_name, $_[0]->name;
}

1;

package Dango::Object::ApplicationRole;
use strict;
use warnings;
use Dango::Object::Base;
push our @ISA, qw(Dango::Object::Base);

sub new_from_name {
    return bless {name => $_[1]}, $_[0];
}

sub type {
    return 'app_role';
}

sub as_testable {
    return sprintf 'app_role %s',
        $_[0]->name;
}

1;

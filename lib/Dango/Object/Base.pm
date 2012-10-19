package Dango::Object::Base;
use strict;
use warnings;

sub type {
    die "|type| not implemented for " . ref $_[0];
}

sub name {
    return $_[0]->{name};
}

sub storage_set_name {
    return $_[0]->{storage_set_name}; # or undef
}

sub parent_name {
    die "not implemented";
}

sub suffixes {
    if (@_ > 1) {
        $_[0]->{suffixes} = $_[1];
    }
    return $_[0]->{suffixes} ||= [];
}

1;

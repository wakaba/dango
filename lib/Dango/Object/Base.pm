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
    return $_[0]->{suffixes} ||= [];
}

sub add_suffix {
    my ($self, $type) = @_;
    push @{$_[0]->{suffixes} ||= []}, {type => $type};
}

1;

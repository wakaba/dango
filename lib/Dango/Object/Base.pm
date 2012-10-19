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

sub has_prop {
    my ($self, $n) = @_;
    return defined $self->{props}->{$n};
}

sub set_prop {
    my ($self, $n, $v) = @_;
    $self->{props}->{$n} = $v;
}

sub get_prop_keys {
    my $self = shift;
    return keys %{$self->{props} or {}};
}

sub get_prop {
    my ($self, $n) = @_;
    return $self->{props}->{$n};
}

sub _as_testable {
    die "not implemented";
}

sub as_testable {
    my $self = shift;
    return join "\n",
        $self->_as_testable,
        map { "  .$_" } map { ref $_->[1] eq 'HASH' ? $_->[0] . ' <- ' . join ',', sort { $a cmp $b } keys %{$_->[1]} : $_->[0] . ' = ' . $_->[1] } map { [$_ => $self->get_prop($_)] } sort { $a cmp $b } ($self->get_prop_keys);
}

1;

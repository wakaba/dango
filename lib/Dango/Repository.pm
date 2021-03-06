package Dango::Repository;
use strict;
use warnings;

sub new {
    return bless {}, $_[0];
}

sub add_object {
    my ($self, $obj) = @_;
    my $obj_type = $obj->type;
    if ({
        storage_set => 1,
        storage_role => 1,
        app_role => 1,
    }->{$obj_type}) {
        $self->{$obj_type}->{$obj->name} = $obj;
    } elsif ({
        db_set => 1,
        suffix_type => 1,
    }->{$obj_type}) {
        $self->{$obj_type}->{$obj->storage_set_name}->{$obj->name} = $obj;
    } elsif ($obj_type eq 'db' or $obj_type eq 'table') {
        $self->{$obj_type}->{$obj->storage_set_name}->{$obj->name, map { $_->{name} } @{$obj->suffixes}} = $obj;
    } elsif ({table_set => 1, suffix => 1}->{$obj_type}) {
        $self->{$obj_type}->{$obj->storage_set_name}->{$obj->parent_name}->{$obj->name} = $obj;
    } else {
        die "$obj_type not supported";
    }
}

sub has_object {
    my ($self, $obj) = @_;
    my $obj_type = $obj->type;
    if ({
        storage_set => 1,
        storage_role => 1,
        app_role => 1,
    }->{$obj_type}) {
        return !!$self->{$obj_type}->{$obj->name};
    } elsif ({
        db_set => 1,
        suffix_type => 1,
    }->{$obj_type}) {
        return !!$self->{$obj_type}->{$obj->storage_set_name}->{$obj->name};
    } elsif ($obj_type eq 'db' or $obj_type eq 'table') {
        return !!$self->{$obj_type}->{$obj->storage_set_name}->{$obj->name, map { $_->{name} } @{$obj->suffixes}};
    } elsif ({table_set => 1, suffix => 1}->{$obj_type}) {
        return !!$self->{$obj_type}->{$obj->storage_set_name}->{$obj->parent_name}->{$obj->name};
    } else {
        die "$obj_type not supported";
    }
}

sub get_storage_set {
    my ($self, $storage_set_name) = @_;
    return $self->{storage_set}->{$storage_set_name}; # or undef
}

sub get_db_set {
    my ($self, $storage_set, $db_set_name) = @_;
    return $self->{db_set}->{$storage_set->name}->{$db_set_name}; # or undef
}

sub get_table_set {
    my ($self, $storage_set, $db_set, $name) = @_;
    return $self->{table_set}->{$storage_set->name}->{$db_set->name}->{$name}; # or undef
}

sub get_suffix_type {
    my ($self, $storage_set, $suffix_type_name) = @_;
    return $self->{suffix_type}->{$storage_set->name}->{$suffix_type_name}; # or undef
}

sub get_suffix {
    my ($self, $storage_set, $suffix_type, $name) = @_;
    return $self->{suffix}->{$storage_set->name}->{$suffix_type->name}->{$name}; # or undef
}

sub get_storage_role {
    my ($self, $name) = @_;
    return $self->{storage_role}->{$name}; # or undef
}

sub get_db {
    my ($self, $storage_set, $name, $suffixes) = @_;
    return $self->{db}->{$storage_set->name}->{$name, map { $_->{name} } @$suffixes}; # or undef
}

sub for_each_storage_set {
    my ($self, $code, @args) = @_;
    for (values %{$self->{storage_set} or {}}) {
        $code->($_, @args) if $_;
    }
}

sub for_each_storage_role {
    my ($self, $code, @args) = @_;
    for (values %{$self->{storage_role} or {}}) {
        $code->($_, @args) if $_;
    }
}

sub for_each_db {
    my ($self, $storage_set, $code, @args) = @_;
    for (values %{$self->{db}->{$storage_set->name} or {}}) {
        $code->($_, @args) if $_;
    }
}

sub for_each_table {
    my ($self, $storage_set, $code, @args) = @_;
    for (values %{$self->{table}->{$storage_set->name} or {}}) {
        $code->($_, @args) if $_;
    }
}

sub as_testable {
    my $self = shift;
    my $result = '';
    for my $storage_role_name (sort { $a cmp $b } keys %{$self->{storage_role} or {}}) {
        my $storage_role = $self->{storage_role}->{$storage_role_name};
        $result .= $storage_role->as_testable . "\n";
    }
    for my $app_role_name (sort { $a cmp $b } keys %{$self->{app_role} or {}}) {
        my $app_role = $self->{app_role}->{$app_role_name};
        $result .= $app_role->as_testable . "\n";
    }
    for my $storage_set_name (sort { $a cmp $b } keys %{$self->{storage_set} or {}}) {
        my $storage_set = $self->{storage_set}->{$storage_set_name};
        $result .= $storage_set->as_testable . "\n";
        for my $suffix_type_name (sort { $a cmp $b } keys %{$self->{suffix_type}->{$storage_set_name} or {}}) {
            my $suffix_type = $self->{suffix_type}->{$storage_set_name}->{$suffix_type_name};
            $result .= $suffix_type->as_testable . "\n";
            for my $suffix_name (sort { $a cmp $b } keys %{$self->{suffix}->{$storage_set_name}->{$suffix_type_name} or {}}) {
                my $suffix = $self->{suffix}->{$storage_set_name}->{$suffix_type_name}->{$suffix_name};
                $result .= $suffix->as_testable . "\n";
            }
        }
        for my $db_set_name (sort { $a cmp $b } keys %{$self->{db_set}->{$storage_set_name} or {}}) {
            my $db_set = $self->{db_set}->{$storage_set_name}->{$db_set_name};
            $result .= $db_set->as_testable . "\n";
            for my $table_set_name (sort { $a cmp $b } keys %{$self->{table_set}->{$storage_set_name}->{$db_set_name} or {}}) {
                my $table_set = $self->{table_set}->{$storage_set_name}->{$db_set_name}->{$table_set_name};
                $result .= $table_set->as_testable . "\n";
            }
        }
        for my $db_name (sort { $a cmp $b } keys %{$self->{db}->{$storage_set_name} or {}}) {
            my $db = $self->{db}->{$storage_set_name}->{$db_name};
            $result .= $db->as_testable . "\n";
        }
        for my $table_name (sort { $a cmp $b } keys %{$self->{table}->{$storage_set_name} or {}}) {
            my $table = $self->{table}->{$storage_set_name}->{$table_name};
            $result .= $table->as_testable . "\n";
        }
    }
    return $result;
}

1;

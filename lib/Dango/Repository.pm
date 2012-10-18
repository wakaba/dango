package Dango::Repository;
use strict;
use warnings;

sub new {
    return bless {}, $_[0];
}

sub add_object {
    my ($self, $obj) = @_;
    my $obj_type = $obj->type;
    if ($obj_type eq 'storage_set') {
        $self->{$obj_type}->{$obj->name} = $obj;
    } elsif ({db_set => 1, table_suffix_type => 1}->{$obj_type}) {
        $self->{$obj_type}->{$obj->storage_set_name}->{$obj->name} = $obj;
    } elsif ({table_set => 1, table_suffix => 1}->{$obj_type}) {
        $self->{$obj_type}->{$obj->storage_set_name}->{$obj->parent_name}->{$obj->name} = $obj;
    } else {
        die "$obj_type not supported";
    }
}

sub has_object {
    my ($self, $obj) = @_;
    my $obj_type = $obj->type;
    if ($obj_type eq 'storage_set') {
        return !!$self->{$obj_type}->{$obj->name};
    } elsif ({db_set => 1, table_suffix_type => 1}->{$obj_type}) {
        return !!$self->{$obj_type}->{$obj->storage_set_name}->{$obj->name};
    } elsif ({table_set => 1, table_suffix => 1}->{$obj_type}) {
        return !!$self->{$obj_type}->{$obj->storage_set_name}->{$obj->parent_name}->{$obj->name};
    } else {
        die "$obj_type not supported";
    }
}

sub get_db_set {
    my ($self, $storage_set, $db_set_name) = @_;
    return $self->{db_set}->{$storage_set->name}->{$db_set_name}; # or undef
}

sub get_table_suffix_type {
    my ($self, $storage_set, $table_suffix_type_name) = @_;
    return $self->{table_suffix_type}->{$storage_set->name}->{$table_suffix_type_name}; # or undef
}

sub as_testable {
    my $self = shift;
    my $result = '';
    for my $storage_set_name (sort { $a cmp $b } keys %{$self->{storage_set} or {}}) {
        my $storage_set = $self->{storage_set}->{$storage_set_name};
        $result .= $storage_set->as_testable . "\n";
        for my $table_suffix_type_name (sort { $a cmp $b } keys %{$self->{table_suffix_type}->{$storage_set_name} or {}}) {
            my $table_suffix_type = $self->{table_suffix_type}->{$storage_set_name}->{$table_suffix_type_name};
            $result .= $table_suffix_type->as_testable . "\n";
            for my $table_suffix_name (sort { $a cmp $b } keys %{$self->{table_suffix}->{$storage_set_name}->{$table_suffix_type_name} or {}}) {
                my $table_suffix = $self->{table_suffix}->{$storage_set_name}->{$table_suffix_type_name}->{$table_suffix_name};
                $result .= $table_suffix->as_testable . "\n";
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
    }
    return $result;
}

1;

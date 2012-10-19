use strict;
use warnings;
use Path::Class;
use lib glob file(__FILE__)->dir->parent->subdir('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::More;
use Test::HTCT::Parser;
use Dango::Parser;
use Test::Differences;

for my $file_name (qw(objects.dat props.dat)) {
    test {
        my $c = shift;

        for_each_test file(__FILE__)->dir->subdir('data')->file($file_name), {
            data => {is_prefixed => 1},
            parsed => {is_prefixed => 1},
            errors => {},
        }, sub {
            my $test = shift;
            
            my $parser = Dango::Parser->new;
            my $errors = '';
            $parser->onerror(sub {
                my %args = @_;
                $errors .= "$args{message} at line $args{line} ($args{line_data})\n";
            });

            my $is_error = !$parser->parse_char_string($test->{data}->[0]);
            is !!$is_error, !!$errors;

            $test->{parsed}->[0] .= "\n" if length $test->{parsed}->[0];
            eq_or_diff $parser->repository->as_testable, $test->{parsed}->[0];

            $test->{errors}->[0] = '' unless $test->{errors};
            $test->{errors}->[0] .= "\n" if length $test->{errors}->[0];
            eq_or_diff $errors, $test->{errors}->[0];
        };

        done $c;
    } name => $file_name;
}

run_tests;

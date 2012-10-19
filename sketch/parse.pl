use strict;
use warnings;
use Dango::Parser;

local $/ = undef;
my $data = <>;

my $parser = Dango::Parser->new;
$parser->parse_char_string($data);

my $repo = $parser->repository;

print $repo->as_testable;

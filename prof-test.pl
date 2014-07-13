use lib '../lib';
use Test::More;
use REST::Neo4p;
use REST::Neo4p::Batch;
use List::MoreUtils qw(pairwise);

use strict;
use warnings;
no warnings qw(once);

my $TEST_SERVER = 'http://127.0.0.1:7474';
my $NUM = 100;

REST::Neo4p->connect($TEST_SERVER);

my @bunch = map { "new_node_$_" } (1..$NUM);
my @nodes;
my $idx;
batch {
my $idx = REST::Neo4p::Index->new('node','bunch');
@nodes = map { REST::Neo4p::Node->new({name => $_}) }  @bunch;
pairwise { $idx->add_entry($a, name => $b) } @nodes, @bunch;
$nodes[$_]->relate_to($nodes[$_+1],'next_node') for (0..$#nodes-1);
} 'keep_objs';
foreach (@nodes) {
  isa_ok($_,'REST::Neo4p::Node');
}
done_testing;

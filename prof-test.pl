#-*-perl-*-
#$Id: 010_batch_synopsis.t 275 2013-11-09 23:32:36Z maj $
use lib '../lib';
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
} 'discard_objs';
$idx = REST::Neo4p->get_index_by_name('bunch' => 'node');
my ($the_99th_node) = $nodes[98];
$the_99th_node->get_property('name');
my ($points_to_100th_node) = $the_99th_node->get_outgoing_relationships;
my ($the_100th_node) = $idx->find_entries( name => 'new_node_100');


END {
  CLEANUP : {
      print "cleanup\n";
      my @nodes = $idx->find_entries('name:*') if $idx;
      for my $n (@nodes) {
	  print $$n,"\n";
	  $_->remove for $n->get_all_relationships;
      }
      $_->remove for @nodes;
      $idx->remove if $idx;
  }
}

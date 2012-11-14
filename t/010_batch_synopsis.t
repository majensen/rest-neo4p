#-*-perl-*-
#$Id: 010_batch_synopsis.t 17684 2012-09-23 01:12:42Z jensenma $
use Test::More qw(no_plan);
use Test::Exception;
use Module::Build;
use lib '../lib';
use REST::Neo4p;
use REST::Neo4p::Batch;
use List::MoreUtils qw(pairwise);

use strict;
use warnings;
no warnings qw(once);

my $build;
eval {
    $build = Module::Build->current;
};
my $TEST_SERVER = $build ? $build->notes('test_server') : 'http://127.0.0.1:7474';
my $num_live_tests = 1;

my $not_connected;
eval {
  REST::Neo4p->connect($TEST_SERVER);
};
if ( my $e = REST::Neo4p::CommException->caught() ) {
  $not_connected = 1;
  diag "Test server unavailable : ".$e->message;
}

SKIP : {
  skip 'no local connection to neo4j', $num_live_tests if $not_connected;

  my @bunch = map { "new_node_$_" } (1..100);
  my @nodes;
  batch {
      ok my $idx = REST::Neo4p::Index->new('node','bunch');
      ok @nodes = map { REST::Neo4p::Node->new({name => $_}) }  @bunch;
      pairwise { $idx->add_entry($a, name => $b) } @nodes, @bunch;
      ok($nodes[$_]->relate_to($nodes[$_+1],'next_node')) for (0..$#nodes-1);
      diag("this may take a while ...");
  } 'keep_objs';

  ok my $idx = REST::Neo4p->get_index_by_name('bunch' => 'node');
  ok my ($the_99th_node) = $nodes[98];
  is $the_99th_node->get_property('name'), 'new_node_99';
  my ($points_to_100th_node) = $the_99th_node->get_outgoing_relationships;
  my ($the_100th_node) = $idx->find_entries( name => 'new_node_100');
  
  CLEANUP : {
      my @nodes = $idx->find_entries('name:*');
      for my $n (@nodes) {
	  ok ($_->remove, 'remove relationship') for $n->get_all_relationships;
      }
      ok($_->remove,'remove node') for @nodes;
      ok $idx->remove, 'remove index';
  }
}

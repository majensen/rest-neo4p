#-*-perl-*-
#$Id$
use Test::More qw(no_plan);
use Test::Exception;
use Module::Build;
use lib '../lib';
use REST::Neo4p;
use REST::Neo4p::Batch;
use strict;
use warnings;
no warnings qw(once);

my $build;
my ($user,$pass);

eval {
    $build = Module::Build->current;
    $user = $build->notes('user');
    $pass = $build->notes('pass');
};
my $TEST_SERVER = $build ? $build->notes('test_server') : 'http://127.0.0.1:7474';
my $num_live_tests = 59;

my $not_connected;
eval {
  REST::Neo4p->connect($TEST_SERVER,$user,$pass);
};
if ( my $e = REST::Neo4p::CommException->caught() ) {
  $not_connected = 1;
  diag "Test server unavailable : tests skipped";
}

my ($idx,$idx2);
SKIP : {
  skip 'no local connection to neo4j', $num_live_tests if $not_connected;

  my $node_assigned_inside_batch;
  my $rel;
  ok( !(
  batch {
      ok (REST::Neo4p->agent->batch_mode, 'agent now in batch mode');
      ok $idx = REST::Neo4p::Index->new(node => 'test_node'), 'make an index inside batch';
      my $name = "__test_node";
      my @names = map { $name.$_ } (1..10);
      
      ok({my @nodes = map { REST::Neo4p::Node->new({ name => $name.$_, value => $_*5})} (1..10)},'make some nodes inside batch');
      ok($idx->add_entry($nodes[$_], name => $names[$_] ),"add entry inside batch") for (0..9);
      ok( $node_assigned_inside_batch = $nodes[0], 'assign node inside batch to var declared outside batch');
      ok $rel =  $nodes[0]->relate_to($nodes[1], 'one2two'), 'create relationship inside batch';
  } ('keep_objs')
      ), 'batch ran without errors');
  ok !REST::Neo4p->agent->batch_mode, 'agent not now in batch mode';
  ok $idx = REST::Neo4p->get_index_by_name('test_node','node'), 'got index outside batch';
  ok !$idx->is_batch;
  $DB::single=1;
  for (1..10) {
      my ($n) = $idx->find_entries(name => "__test_node$_");
      ok $n, 'got node outside batch';
      ok !$n->is_batch, 'and not a batch node';
  }

  ok $node_assigned_inside_batch, 'node assigned inside batch';
  ok !$node_assigned_inside_batch->is_batch, 'and not a batch node';

  is $node_assigned_inside_batch->get_property('name'),'__test_node1', 'and property correct';

  ok $rel, 'reln assigned inside batch';
  ok !$rel->is_batch, 'and not a batch relationship';
  is $rel->type, 'one2two', 'correct type';

  ok  my $idx2 = REST::Neo4p::Index->new('node' => 'pals_of_bob'), "new index";
  my $name = 'fred';
  my $node2;
  batch {
      $node2 = REST::Neo4p::Node->new({name => $name});
      ok $idx2->add_entry($node2, name => $node2->get_property('name')), 'try to add a batch-set node by referring to get_property in batch mode...';
  } 'keep_objs';
  my ($node3) = $idx2->find_entries(name => $name);
  ok !$node3, '..but it does not work';

}

END {
  CLEANUP : {
      my @nodes = $idx->find_entries('name:*') if $idx;
      for my $n (@nodes) {
	  ok ($_->remove, 'remove relationship') for $n->get_all_relationships;
      }
      ok($_->remove,'remove node') for @nodes;
      ok ($idx->remove, 'remove index') if $idx;
      ok ($idx2->remove, 'remove index') if $idx2;
  }
}

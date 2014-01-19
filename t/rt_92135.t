#$Id$
use Test::More qw/no_plan/;
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
my $test_index = '828e55b1_d050_41e9_8d9e_68c25f72275c';
my ($dealerNode, $index);
eval {
    $build = Module::Build->current;
    $user = $build->notes('user');
    $pass = $build->notes('pass');
};
my $TEST_SERVER = $build ? $build->notes('test_server') : 'http://127.0.0.1:7474';
my $num_live_tests = 6;

my $not_connected;
eval {
  REST::Neo4p->connect($TEST_SERVER,$user,$pass);
};
if ( my $e = REST::Neo4p::CommException->caught() ) {
  $not_connected = 1;
  diag "Test server unavailable : tests skipped";
}

SKIP : {
  skip 'no local connection to neo4j', $num_live_tests if $not_connected;
  my $version = REST::Neo4p->neo4j_version;
  my $VERSION_OK = REST::Neo4p->_check_version(2,0);
  my $source = 'flerb';
  SKIP : {
    skip "Server version $version < 2.0", $num_live_tests unless $VERSION_OK;
    eval {
      batch {
      ok $dealerNode = REST::Neo4p::Node->new({source => $source}), 'create node in batch';
      ok $dealerNode->set_labels("Dealer"), 'set label in batch';
    } 'keep_objs';
    };
    if ($@) { fail $@ } else { pass 'batch ran ok' }
    isa_ok $dealerNode, 'REST::Neo4p::Node';
    ok grep (/Dealer/,$dealerNode->get_labels), 'node label is set after batch run';
    is $dealerNode->get_property('source'), $source, 'source property is set after batch';

  }
  }


END {
  $dealerNode && $dealerNode->remove;
  $index && $index->remove;
}

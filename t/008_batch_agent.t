#-*-perl-*-
#$Id: 008_batch_agent.t 17684 2012-09-23 01:12:42Z jensenma $#
use Test::More qw(no_plan);
use Test::Exception;
use Module::Build;
use lib '../lib';
use strict;
use warnings;
no warnings qw(once);

my $build;
eval {
    $build = Module::Build->current;
};
my $TEST_SERVER = $build ? $build->notes('test_server') : 'http://127.0.0.1:7474';
my $num_live_tests = 1;

use_ok('REST::Neo4p');

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
  ok my $agent = $REST::Neo4p::AGENT, 'got agent';
  throws_ok { $agent->batch_length } 'REST::Neo4p::LocalException', 'not in batch mode ok';
  ok $agent->batch_mode(1), 'set batch mode';
  ok !$agent->batch_length, 'queue empty';
  is $agent->get_node(1), '{1}', 'add to batch queue with get_node';
  is $agent->get_relationship(3), '{2}', 'add to batch queue with get_relationship';
  is $agent->get_data(qw(node index fred)),'{3}', 'add to batch queue with get_data';
  is $agent->batch_length, 3, 'batch length';
  is @{$agent->{__batch_queue}}, 3, 'actual queue array length';
  my $response_content;
  lives_ok { $response_content = $agent->execute_batch } ;
  ok -e $response_content, 'got responses in tmpfile';
  is $agent->batch_length, 0, 'queue length reset to 0';
  ok !defined $agent->{__batch_queue}, 'queue reset';
  CLEANUP : {
      1;
  }
}

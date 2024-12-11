use Test::More tests => 29;
use Test::Exception;
use Module::Build;
use lib '../lib';
use lib 'lib';
use lib 't/lib';
use REST::Neo4p;
use Neo4p::Test;
use Neo4p::Connect ':cypher_params_v2';
use strict;
use warnings;
no warnings qw(once);
my @cleanup;

#$SIG{__DIE__} = sub { print $_[0] };
my $build;
my ($user,$pass) = @ENV{qw/REST_NEO4P_TEST_USER REST_NEO4P_TEST_PASS/};

eval {
  $build = Module::Build->current;
  $user = $build->notes('user');
  $pass = $build->notes('pass');
};

my $TEST_SERVER = $build ? $build->notes('test_server') : $ENV{REST_NEO4P_TEST_SERVER} // 'http://127.0.0.1:7474';

my $num_live_tests = 29;
my $not_connected = connect($TEST_SERVER,$user,$pass);
diag "Test server unavailable (".$not_connected->message.") : tests skipped" if $not_connected;

SKIP : {
  skip "Neo4j server version >= 2.0.0-M02 required, skipping...", $num_live_tests unless  REST::Neo4p->_check_version(2,0,0,2);

  skip 'Returning entities via tx endpoint needs either Driver agent or Neo4j 3.5+', $num_live_tests
    unless REST::Neo4p->_check_version(3,5,0,0)
    || REST::Neo4p->agent->isa('REST::Neo4p::Agent::Neo4j::Driver');
  # There is a known bug in _process_row/_response_entity in REST::Neo4p::Query
  # that can prevent correct parsing of metadata for entities returned via the
  # transaction endpoint. The metadata format varied between Neo4j versions.
  # REST::Neo4p 0.3012-0.3030 worked correctly on some (not all) Neo4j versions.

my $neo4p = 'REST::Neo4p';
my ($n, $m);
SKIP : {
  skip 'no local connection to neo4j', $num_live_tests if $not_connected;
  ok my $t = Neo4p::Test->new, 'test graph object';

  ok $t->create_sample, 'create sample graph';
  is $neo4p->q_endpoint, 'cypher', 'endpt starts out as cypher';
  ok $neo4p->begin_work, 'begin transaction';
  is $neo4p->q_endpoint, 'transaction', 'endpt now transaction';
  my $lbl = $t->lbl;
  my $stmt1 =<<STMT1;
 MATCH (n:$lbl)-[r:good]-(m:$lbl)
 WHERE n.name = 'I'
 WITH n,m
 MERGE (n)-[:bosom]->(m)
STMT1
  my $stmt2 =<<STMT2;
  MATCH (n:$lbl)-[:umm]-(m:$lbl)
  WITH n,m
  MERGE (m)-[:prettygood]->(u)
  SET u:$lbl
  RETURN u
STMT2
  my $uuid = $t->uuid;
  my $stmt3=<<STMT3;
  MATCH (m:$lbl)-[:prettygood]->(u:$lbl)
  SET u.name='Fred',u.uuid='$uuid'
  RETURN u, u.name
STMT3
  ok (($n) = $t->find_sample(name => 'I'));
  my @r = $n->get_relationships;
  is @r, 4, '4 relationships before execute';
  ok my $q = REST::Neo4p::Query->new($stmt1), 'statement 1';
  $q->{RaiseError} = 1;
  ok defined $q->execute, 'execute statment 1';
  @r = $n->get_relationships;
  is @r, 4, 'executed, but still only 4 relationships';
  ok $neo4p->commit, 'commit';
  ok !$neo4p->_transaction, 'transaction cleared';
  is $neo4p->q_endpoint, 'cypher', 'endpoint reset to cypher';
  @r = $n->get_relationships;
  is @r, 5, 'committed, now 5 relationships';
  $q = REST::Neo4p::Query->new($stmt2);
  $q->{RaiseError} = 1;
  my $w = REST::Neo4p::Query->new($stmt3);
  $w->{RaiseError} = 1;
  ($m) = $t->find_sample(name => 'he');
  is scalar $m->get_relationships, 1, 'he has 1 relationship';
  ok $neo4p->begin_work, 'begin transaction';
  ok defined $q->execute(name => 'she'), 'exec stmt 2';
  ok defined $w->execute, 'exec stmt 3';
  is scalar $m->get_relationships, 1, 'he has 1 relationship before rollback';
  ok $neo4p->rollback, 'rollback';
  ok !$neo4p->_transaction, 'transaction cleared';
  is $neo4p->q_endpoint, 'cypher', 'endpoint reset to cypher';
  is scalar $m->get_relationships, 1, 'he has 1 relationship before rollback';
  ok $neo4p->begin_work, 'begin transaction';
  ok defined $q->execute(name => 'she'), 'exec stmt 2';
  ok defined $w->execute, 'exec stmt 3';
  $w->{ResponseAsObjects} = undef;
  my $row = $w->fetch;
  is_deeply $row, [ { _node => $row->[0]{_node}, name => 'Fred', uuid => $uuid }, 'Fred' ], 'check simple txn row return';
  ok $neo4p->commit, 'commit';
  is scalar($m->get_relationships), 2, 'now he has 2 relationships';
}
}


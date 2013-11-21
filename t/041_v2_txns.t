#$Id$
use Test::More;
use Test::Exception;
use Module::Build;
use lib '../lib';
use lib 'lib';
use lib 't/lib';
use Neo4p::Test;
use strict;
use warnings;
no warnings qw(once);
my @cleanup;
use_ok('REST::Neo4p');

my $build;
my ($user,$pass);

eval {
  $build = Module::Build->current;
  $user = $build->notes('user');
  $pass = $build->notes('pass');
};

my $TEST_SERVER = $build ? $build->notes('test_server') : 'http://127.0.0.1:7474';
my $num_live_tests = 1;
my $not_connected;
eval {
  REST::Neo4p->connect($TEST_SERVER,$user,$pass);
};
if ( my $e = REST::Neo4p::CommException->caught() ) {
  $not_connected = 1;
  diag "Test server unavailable : tests skipped";
}

plan skip_all => "Neo4j server version >= 2.0.0-M02 required, skipping..." unless
  REST::Neo4p->_check_version(2,0,0,2);

my $neo4p = 'REST::Neo4p';
my ($n, $m);
SKIP : {
  skip 'no local connection to neo4j', $num_live_tests if $not_connected;
  ok my $t = Neo4p::Test->new, 'test graph object';
  ok $t->create_sample, 'create sample graph';
  is $neo4p->q_endpoint, 'cypher', 'endpt starts out as cypher';
  ok $neo4p->begin_work, 'begin transaction';
  is $neo4p->q_endpoint, 'transaction', 'endpt now transaction';
  my $idx_name = $t->nix->name;
  my $stmt1 =<<STMT1;
 START n = node:${idx_name}(name = 'I')
 MATCH n-[r:good]-m
 CREATE n-[s:bosom]->m
STMT1
  my $stmt2 =<<STMT2;
  START n = node:${idx_name}(name = { name })
  MATCH n-[:umm]-m
  CREATE UNIQUE m-[:prettygood]->u
  RETURN u
STMT2
  my $uuid = $t->uuid;
  my $stmt3=<<STMT3;
  START m = node:${idx_name}("name:*")
  MATCH m,u
  WHERE m-[:prettygood]->u
  SET u.name='Fred',u.uuid='$uuid'
  RETURN u, u.name
STMT3
  ok (($n) = $t->nix->find_entries(name => 'I'));
  my @r = $n->get_relationships;
  is @r, 4, '4 relationships before execute';
  ok my $q = REST::Neo4p::Query->new($stmt1), 'statement 1';
  $q->{RaiseError} = 1;
  ok my $rc = $q->execute, 'execute statment 1';
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
  ($m) = $t->nix->find_entries(name => 'he');
  is scalar $m->get_relationships, 1, 'he has 1 relationship';
  $DB::single=1;
  ok $neo4p->begin_work, 'begin transaction';
  ok $rc = $q->execute(name => 'she'), 'exec stmt 2';
  ok $rc = $w->execute, 'exec stmt 3';
  is scalar $m->get_relationships, 1, 'he has 1 relationship before rollback';
  ok $neo4p->rollback, 'rollback';
  ok !$neo4p->_transaction, 'transaction cleared';
  is $neo4p->q_endpoint, 'cypher', 'endpoint reset to cypher';
  is scalar $m->get_relationships, 1, 'he has 1 relationship before rollback';
  ok $neo4p->begin_work, 'begin transaction';
  ok $rc = $q->execute(name => 'she'), 'exec stmt 2';
  ok $rc = $w->execute, 'exec stmt 3';
  ok $neo4p->commit, 'commit';
  is scalar($m->get_relationships), 2, 'now he has 2 relationships';  
  $_->remove for $n->get_relationships;
  $_->remove for $m->get_relationships;
}

done_testing;

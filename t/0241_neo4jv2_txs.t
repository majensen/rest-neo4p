#-*-perl-*-
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
 CREATE n-[r:bosom]-m
STMT1
  
  my $stmt2 =<<STMT2;
  START n = node:${idx_name}(name = 'she')
  MATCH n-[:umm]-m
  CREATE UNIQUE m-[:prettygood]->u
STMT2

  my $uuid = $t->uuid;
  my $stmt3=<<STMT3;
  MATCH m,u
  WHERE m-[:prettygood]->u
  SET u.name='Fred',u.uuid='$uuid'
STMT3

  ok my $q = REST::Neo4p::Query->new($stmt1), 'statement 1';
  ok $q->execute, 'execute statment 1';
  ok my ($n) = $t->nix->find_entries(name => 'I');
  my @r = $n->get_relationships;
  is @r, 4, 'executed, but still only 4 relationships';
  ok $neo4p->commit, 'commit';
  ok !$neo4p->_transaction, 'transaction cleared';
  is $neo4p->q_endpoint, 'cypher', 'endpt reset';
  @r = $n->get_relationships;
  is @r, 5, 'committed, now 5 relationships';
  my $r = grep { 
    $_->type =~ /bosom/i and
      $_->end_node->get_property('name') eq 'he'
    } @r;
  1;
  $r->remove;
}

done_testing;

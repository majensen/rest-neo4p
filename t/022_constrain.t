#-*-perl-*-
#$Id$#
use Test::More qw(no_plan);
use Test::Exception;
use Module::Build;
use lib '../lib';
use REST::Neo4p;
use strict;
use warnings;
no warnings qw(once);

my $build;
eval {
    $build = Module::Build->current;
};
my $TEST_SERVER = $build ? $build->notes('test_server') : 'http://127.0.0.1:7474';
my $num_live_tests = 47;

my $not_connected;
eval {
  REST::Neo4p->connect($TEST_SERVER);
};
if ( my $e = REST::Neo4p::CommException->caught() ) {
  $not_connected = 1;
  diag "Test server unavailable : ".$e->message;
}

use_ok ('REST::Neo4p::Constrain');

ok my $c1 = create_constraint( 
  tag => 'module',
  type => 'node_property',
  condition => 'all',
  constraints => {
    entity => 'module',
    namespace => qr/([a-z0-9_]+)+(::[a-z0-9_])*/i,
    exports => []
   }
), 'create module node_property constraint';

isa_ok($c1,'REST::Neo4p::Constraint::NodeProperty');

ok my $c2 = create_constraint( 
  tag => 'method',
  type => 'node_property',
  condition => 'all',
  constraints => {
    entity => 'method',
    name => qr/[a-z0-9_]+/i,
    return => qr/^(scalar|array|hash)(ref)?$/
   }
), 'create method node_property constraint';

isa_ok($c2,'REST::Neo4p::Constraint::NodeProperty');

ok my $c3 = create_constraint( 
  tag => 'how_contained',
  type => 'relationship_property',
  rtype => 'contains',
  condition => 'all',
  constraints =>  {
    contained_by => qr/^declaration|import$/
   }
), 'create how_contained relationship_property constraint';

isa_ok($c3,'REST::Neo4p::Constraint::RelationshipProperty');

ok my $c4 = create_constraint(
  tag => 'contains',
  type => 'relationship',
  rtype => 'contains',
  constraints => [ {'module' => 'method'} ]
), 'create contains relationship constraint';

isa_ok($c4, 'REST::Neo4p::Constraint::Relationship');

ok my $c5 = create_constraint(
  tag => 'allowed_types',
  type => 'relationship_type',
  constraints => [ 'contains' ]
), 'create relationship type constraint';

isa_ok($c5, 'REST::Neo4p::Constraint::RelationshipType');

lives_ok { constrain() } 'set up automatic constraints';

SKIP : {
  skip 'no local connection to neo4j, live tests not performed', $num_live_tests if $not_connected;
  CLEANUP : {
    1;
  }
}

use v5.10;
use Test::More;
use Test::Exception;
use Set::Scalar;
use File::Spec;
use lib qw|. ../lib ../../lib/|;
use REST::Neo4p::Agent;
use strict;
use warnings;

my $dir = (-d 't' ? 'neodriver' : '.');

unless (eval "require NeoCon; 1") {
  diag "Issue with NeoCon: ".$@;
  diag "Need docker for these tests";
  pass;
  done_testing;
}

$DB::single=1;
my $docker = NeoCon->new(
  tag => $ENV{NEOCON_TAG} // 'neo4j:3.5',
  delay => 15,
  load => File::Spec->catfile($dir,'samples/test.cypher'),
 );

if (!$docker->start) {
  diag "Docker container startup error, skipping";
  diag $docker->error;
  pass;
  done_testing;
}

my ($agent, $result, $got, $exp, $node, $reln);

ok $agent = REST::Neo4p::Agent->new( agent_module => 'Neo4j::Driver' );
ok $agent->connect('http://localhost:'.$docker->ports->{7474});

# get ids of nodes and relationships
my %ids;
$result = $agent->run_in_session('match (n) return n.name as name, id(n) as id');
while (my $rec = $result->fetch) {
  $ids{$rec->get('name')} = $rec->get('id');
}

$result = $agent->get_propertykeys;
$got = Set::Scalar->new();
$exp = Set::Scalar->new('state','date','name','rem');
while (my $rec = $result->fetch) {
  $got->insert( $rec->get(0) );
}

is $got, $exp;

$result = $agent->get_node($ids{'you'});
$node = $result->fetch->get(0);
is $node->id, $ids{you};
is $node->get('name'), 'you';

$result = $agent->get_node($ids{'she'},'labels');
my $lbls = $result->fetch->get(0);
is_deeply $lbls, ['person'];

$result = $agent->get_node($ids{'he'}, 'properties');
my $props = $result->fetch->get(0);
is_deeply $props, { name => 'he' };

$result = $agent->get_node($ids{'it'}, 'properties', 'name');
is $result->fetch->get(0), 'it';

$result = $agent->get_node($ids{'I'}, 'relationships', 'all');
my @rec;
while (my $rec = $result->fetch) {
  push @rec, $rec->get(0);
}
is scalar @rec, 4;

$result = $agent->get_node($ids{'I'}, 'relationships', 'out');
@rec = ();
while (my $rec = $result->fetch) {
  push @rec, $rec->get(0);
}
is scalar @rec, 2;

$result = $agent->get_node($ids{'I'}, 'relationships', 'in');
@rec = ();
while (my $rec = $result->fetch) {
  push @rec, $rec->get(0);
}
is scalar @rec, 2;

$result = $agent->get_node($ids{'I'}, 'relationships', 'all', 'best');
@rec = ();
while (my $rec = $result->fetch) {
  push @rec, $rec->get(0);
}
is scalar @rec, 2;

$result = $agent->get_node($ids{'I'}, 'relationships', 'in', 'good');
@rec = ();
while (my $rec = $result->fetch) {
  push @rec, $rec->get(0);
}
is scalar @rec, 1;

$DB::single=1;
$result = $agent->get_node($ids{'noone'},'properties','rem');
is $result->fetch->get(0), 'bye';

$result = $agent->delete_node($ids{'noone'}, 'properties', 'rem');
$result = $agent->get_node($ids{'noone'},'properties','rem');
ok $result->fetch;

$result = $agent->get_node($ids{'noone'}, 'labels');
is $result->fetch->get(0)->[0], 'person';
$agent->delete_node($ids{'noone'}, 'labels', 'person');
$result = $agent->get_node($ids{'noone'}, 'labels');
ok !$result->fetch;


1;

done_testing;



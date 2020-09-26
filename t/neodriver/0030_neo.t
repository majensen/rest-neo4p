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

my $docker = NeoCon->new(
  tag => $ENV{NEOCON_TAG} // 'neo4j:3.4',
  delay => 5,
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
  $ids{$rec->get('name')} = 0+$rec->get('id');
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

$result = $agent->get_node($ids{'noone'},'properties','rem');
is $result->fetch->get(0), 'bye';

$result = $agent->get_node($ids{'noone'}, 'labels'); # why does this query return no results (using HTTP endpoint), when executed after delete_node/properties/rem below?
is $result->fetch->get(0)->[0], 'person';

$result = $agent->delete_node($ids{'noone'}, 'properties', 'rem');
$result = $agent->get_node($ids{'noone'},'properties','rem');
ok !$result->fetch->get(0);

$agent->delete_node($ids{'noone'}, 'labels', 'person');
$result = $agent->get_node($ids{'noone'}, 'labels');
ok !@{$result->fetch->get(0)};

ok $agent->get_node($ids{'noone'})->fetch;
ok $agent->delete_node($ids{'noone'});
ok !$agent->get_node($ids{'noone'})->fetch;

$result = $agent->get_relationship('types');
is_deeply [ sort map { $_->get(0) } $result->list ], [sort qw/bosom best umm fairweather good/];

my @rids;
$result = $agent->run_in_session('match ()-[r]->() where type(r)=$type return id(r) as id',{type=>'best'});
while (my $rec = $result->fetch) {
  push @rids, 0+$rec->get('id');
}

$agent->get_relationship($rids[0]);
my $r = $agent->last_result->fetch->get(0);
is $r->type, 'best';

$agent->get_relationship($rids[0],'properties');
is_deeply $r->properties, $agent->last_result->fetch->get(0);

$agent->get_relationship($rids[0],'properties','state');
is $r->get('state'),$agent->last_result->fetch->get(0);

$agent->delete_relationship($rids[0],'properties','state');
$agent->get_relationship($rids[0],'properties');
is_deeply ['date'], [ keys %{$agent->last_result->fetch->get(0)} ];

$agent->delete_relationship($rids[0],'properties');
$agent->get_relationship($rids[0],'properties');
is_deeply {}, $agent->last_result->fetch->get(0);

$agent->delete_relationship($rids[0]);
$agent->get_relationship($rids[0]);
ok !$agent->last_result->fetch;

# post node, relationship

$agent->post_node();
ok my $n = $agent->last_result->fetch->get(0);

$agent->post_node([],{ foo => 'bar' });
ok my $m = $agent->last_result->fetch->get(0);
$agent->get_node($m->id,'properties');
is_deeply $agent->last_result->fetch->get(0), { foo => 'bar' };

$agent->post_node([$n->id, 'labels'],['alien']);
$agent->get_node($n->id,'labels');
is_deeply $agent->last_result->fetch->get(0), ['alien'];

$agent->post_node([$n->id, 'relationships'], { to => 'node/'.$m->id, type => 'squirts', data => {narf => 'crelb'} });
$agent->get_node($m->id, qw/relationships in/);
$r = $agent->last_result->fetch->get(0);
is $r->type, 'squirts';
is_deeply $r->properties, {narf => 'crelb'};
is $r->start_id, $n->id;
is $r->end_id, $m->id;

$agent->put_relationship([ $r->id, 'properties'], {bar => 'quux'});
$agent->get_relationship($r->id, 'properties');
is_deeply $agent->last_result->fetch->get(0), {narf => 'crelb', bar => 'quux'};

# get by label
$DB::single=1;
$agent->get_labels();
is_deeply [ sort map {$_->get(0)} $agent->last_result->list], ['alien','person'];



# node, relationship explicit indexes

# schema constraints
1;

  


1;
done_testing;



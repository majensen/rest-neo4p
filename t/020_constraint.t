#-*-perl-*-
#$Id$
use Test::More tests => 51;
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

use_ok ('REST::Neo4p::Constraint');

my ($person_pc, $pet_pc, $reln_pc, $reln_c, $reln_c2, $reln_tc);

throws_ok { REST::Neo4p::Constraint->new() } qr/requires tag/, 'no args exception';
throws_ok { REST::Neo4p::Constraint->new('$$blurg') } qr/only alphanumeric/, 'bad tag chars exception';
throws_ok { REST::Neo4p::Constraint::NodeProperty->new('blurg',['not correct']) } qr/not a hashref/, 'dies on bad 2nd (constraints) arg';


ok $person_pc = REST::Neo4p::Constraint::NodeProperty->new(
  'person', 
  { name => qr/^[A-Z]/,
    genus => 'Homo',
    language => '+' }
 ), 'node_property constraint';

ok $pet_pc = REST::Neo4p::Constraint::NodeProperty->new(
  'pet', 
  { _condition => 'all',
    name => qr/^[A-Z]/,
    genus => 'Canis' }
), 'node_property constraint';

ok $reln_pc = REST::Neo4p::Constraint::RelationshipProperty->new(
  'acquaintance', 
  { disposition => ['friendly','neutral','antagonistic'] }
), 'relationship_property constraint';

ok $reln_c = REST::Neo4p::Constraint::Relationship->new(
  'reln_c',
  { _relationship_type => 'acquaintance_of', 
    _descriptors => [{'person' => 'person' }] } 
), "relationship constraint";

ok $reln_c2 = REST::Neo4p::Constraint::Relationship->new(
  'reln_c2',
  { _relationship_type => 'pet_of',
    _descriptors => [] }
), "relationship constraint";

ok $reln_tc = REST::Neo4p::Constraint::RelationshipType->new(
  'reln_tc', 
  { _type_list => ['acquaintance_of', 'pet_of']}
), 'relationship_type constraint';

isa_ok($_, 'REST::Neo4p::Constraint') for ($person_pc, $pet_pc,
					   $reln_pc, $reln_c, $reln_tc);

is $person_pc->condition, 'only', 'person_pc condition correct (default)';
is $pet_pc->condition, 'all', 'pet_pc condition correct';
ok $pet_pc->set_condition('only'), 'set condition';
is $pet_pc->condition, 'only', 'set condition works';
ok !$pet_pc->constraints->{_condition}, "pet_pc _condition removed from constraint hash";
is_deeply [sort $reln_tc->type_list], [qw( acquaintance_of pet_of )], 'type_list correct';

is $person_pc->tag, 'person', 'person_pc tag correct';
is $pet_pc->tag, 'pet', 'pet_pc tag correct';
is $reln_pc->tag, 'acquaintance', 'reln_pc tag correct';
is $reln_c->tag, 'reln_c', 'reln_c tag correct';
is $reln_c2->tag, 'reln_c2', 'reln_c2 tag correct';
is $reln_tc->tag, 'reln_tc', 'reln_tc tag correct';

is $person_pc->type, 'node_property', 'person_pc type correct';
is $pet_pc->type, 'node_property', 'pet_pc type correct';
is $reln_pc->type, 'relationship_property', 'reln_pc type correct';
is $reln_c->type, 'relationship', 'reln_c type correct';
is $reln_c2->type, 'relationship', 'reln_c type correct';
is $reln_tc->type, 'relationship_type', 'reln_tc type correct';

ok $person_pc->set_priority(1), 'set person_pc priority';
ok $reln_pc->set_priority(20), 'set reln_pc priority';
ok $reln_tc->set_priority(50), 'set reln_tc priority';
is $person_pc->priority, 1, 'person_pc priority set';
is $reln_pc->priority, 20, 'person_pc priority set';
is $reln_tc->priority, 50, 'person_pc priority set';

$person_pc->add_constraint( species => ['sapiens', 'habilis'] );
ok grep(/species/,keys $person_pc->constraints), 'constraint added';

ok $reln_c->add_constraint( { 'pet' => 'pet' } ), 'add relationship constraint';
ok $reln_c2->add_constraint( { 'pet' => 'person' } ), 'add relationship constraint';
is_deeply $reln_c->constraints->{_descriptors}, [{'person'=>'person'},{'pet' => 'pet'}], 'relationship constraint added';
is_deeply $reln_c2->constraints->{_descriptors}, [{'pet' => 'person'}], 'relationship constraint added';

ok $reln_tc->add_constraint('slave_of'), "relationship type added";
is_deeply [$reln_tc->type_list], [qw( acquaintance_of pet_of slave_of )], "relationship type added";

throws_ok { $reln_c2->add_constraint( { 'slave' => 'person' }) } qr/is not defined/, "bad constraint tag (1) throws";
throws_ok { $reln_c2->add_constraint( { 'person' => 'insect' }) } qr/is not defined/, "bad constraint tag (2) throws";

throws_ok { $person_pc->get_constraint('pet') } 'REST::Neo4p::ClassOnlyException', 'get_constraint() is class-only';

isa_ok(REST::Neo4p::Constraint->get_constraint('pet'), 'REST::Neo4p::Constraint');
is(REST::Neo4p::Constraint->get_constraint('pet')->tag, 'pet', 'got pet constraint');


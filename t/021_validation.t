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

use_ok ('REST::Neo4p::Constraint');

# test validation - property constraints

my $c1 = REST::Neo4p::Constraint::NodeProperty->new(
  'c1',
  {
    name => '',
    rank => [],
    serial_number => qr/^[0-9]+$/,
    army_of => 'one',
    options => [qr/[abc]/]
   }
 );

my @propset;
# 1
# valid for all, only
# invalid for none
push @propset, 
  [
    {
      name => 'Jones',
      rank => 'Corporal',
      serial_number => '147800934',
      army_of => 'one'
     },[1, 1, 0]
    ];
# 2
# valid for all, only
# invalid for none
push @propset, [
  {
    name => 'Jones',
    serial_number => '147800934',
    army_of => 'one'
   }, [1,1,0] 
];

# 3
# valid for all
# invalid for only, none
push @propset, [
  {
    name => 'Jones',
    serial_number => '147800934',
    army_of => 'one',
    extra => 'value'
   }, [1,0,0]
];

# 4
# invalid for all, only
# invalid for none
push @propset, [
  {
    name => 'Jones',
    rank => 'Corporal',
    serial_number => 'THX1138',
    army_of => 'one'
   }, [0,0,0]
];

# 5
# invalid for all, only
# valid for none
push @propset, [
  {
    different => 'altogether'
  }, [0,0,1]
];

# 6
# valid for all, only
# invalid for none
push @propset, [
   {
     name => 'Jones',
     rank => 'Corporal',
     serial_number => '147800934',
     army_of => 'one',
     options => 'a'
    }, [1,1,0]
];

# 7
# invalid for all, only, none
push @propset, [
  {
    name => 'Jones',
    rank => 'Corporal',
    serial_number => '147800934',
    options => 'e'
   }, [0,0,0]
];

my $ctr=0;
foreach (@propset) {
  my $propset = $_->[0];
  my $expected = $_->[1];
  $ctr++;
  $c1->set_condition('all');
  is $c1->validate($propset), $expected->[0], "propset $ctr : all";
  $c1->set_condition('only');
  is $c1->validate($propset), $expected->[1], "propset $ctr : only";
  $c1->set_condition('none');
  is $c1->validate($propset), $expected->[2], "propset $ctr : none";
}

# test validation : relationship constraints

REST::Neo4p::Constraint::NodeProperty->new
(
 'module',
 {
  _condition => 'all',
  entity => 'module',
  namespace => qr/([a-z0-9_]+)+(::[a-z0-9_])*/i,
  exports => []
 }
);

REST::Neo4p::Constraint::NodeProperty->new
(
 'variable',
 {
  _condition => 'all',
  entity => 'variable',
  name => qr/[a-z0-9_]+/i,
  sigil => qr/[\$\@\%]/,
 }
);

REST::Neo4p::Constraint::NodeProperty->new
(
 'method',
 {
  _condition => 'all',
  entity => 'method',
  name => qr/[a-z0-9_]+/i,
  return => qr/^(scalar|array|hash)(ref)?$/
 }
);

REST::Neo4p::Constraint::NodeProperty->new
(
 'parameter',
 {
  _condition => 'all',
  entity => 'parameter',
  type => qr/^(scalar|array|hash)(ref)?$/
 }
);

REST::Neo4p::Constraint::RelationshipProperty->new
(
 'position',
 {
  _condition => 'only',
  position => qr/[0-9]+/
 }
);

my $allowed_has_relns = REST::Neo4p::Constraint::Relationship->new
(
  'allowed_has_relns',
  {
    _condition => 'only',
    _relationship_type => 'has',
    _descriptors => [ {'module' => 'method'},
	     {'method' => 'parameter'} ]
  }
);

my $allowed_contains_relns = REST::Neo4p::Constraint::Relationship->new
(
 'allowed_contains_relns',
 {
     _condition => 'only',
     _relationship_type => 'contains',
     _descriptors  => [ {'module' => 'method'},
		       {'module' => 'variable'},
		       {'method' => 'variable'} ]
 }
);

my $module = {
  entity => 'module',
  namespace => 'Acme::BeesKnees'
};

my $teh_shizznit = {
  entity => 'method',
  name => 'is_teh_shizznit',
  return => 'scalar'
    
};

my $bizzity_bomb = {
  entity => 'method',
  name => 'is_the_bizzity_bomb',
  return => 'scalar'
};

my $variable = {
  entity => 'variable',
  name => 'self',
  sigil => '$'
};

my $parameter = {
  entity => 'parameter',
  name => 'extra',
  type => 'arrayref'
};

my $position = {
  position => 0
};

isa_ok( REST::Neo4p::Constraint->drop_constraint('c1'), 'REST::Neo4p::Constraint');
ok my $position_constraint = REST::Neo4p::Constraint->get_constraint('position');
is $position_constraint->rtype, '*', 'position constraint rtype is wildcard';
ok $position_constraint->validate($position), 'relationship property constraint satisfied by \'position\'';

is $allowed_has_relns->validate( $module => $teh_shizznit, 'has' ), 1, 'module can have method (1)';
is $allowed_has_relns->validate( $module => $bizzity_bomb, 'has'), 1,  'module can have method (2)';
is $allowed_contains_relns->validate( $module => $teh_shizznit, 'contains' ), 1, 'module can also contain a method';
is $allowed_contains_relns->validate( $teh_shizznit => $variable, 'contains'), 1, 'method can contain a variable';
is $allowed_contains_relns->validate( $bizzity_bomb => $parameter, 'contains'),0, 'method cannot contain a parameter';
is $allowed_has_relns->validate( $bizzity_bomb => $variable, 'has'), 0, 'method cannot "have" a variable';
is $allowed_has_relns->validate( $variable => $bizzity_bomb, 'has'), 0, 'variable cannot contain a method';

# test validation : relationship type constraints


SKIP : {
  skip 'no local connection to neo4j, live tests not performed', $num_live_tests if $not_connected;
  my @cleanup;
  my @nodeset;
  foreach (@propset) {
      push @cleanup, my $n = REST::Neo4p::Node->new($_->[0]);
      push @nodeset, [$n,$_->[1]];
  }
  my $ctr=0;
  foreach (@nodeset) {
      my $nodeset = $_->[0];
      my $expected = $_->[1];
      $ctr++;
      $c1->set_condition('all');
      is $c1->validate($nodeset), $expected->[0], "nodeset $ctr : all";
      $c1->set_condition('only');
      is $c1->validate($nodeset), $expected->[1], "nodeset $ctr : only";
      $c1->set_condition('none');
      is $c1->validate($nodeset), $expected->[2], "nodeset $ctr : none";
  }

  push @cleanup, my $module_node = REST::Neo4p::Node->new($module);
  push @cleanup, my $teh_shizznit_node = REST::Neo4p::Node->new($teh_shizznit);
  push @cleanup, my $bizzity_bomb_node = REST::Neo4p::Node->new($bizzity_bomb);
  push @cleanup, my $variable_node = REST::Neo4p::Node->new($variable);
  push @cleanup, my $parameter_node = REST::Neo4p::Node->new($parameter);

  push @cleanup, my $r1 = $module_node->relate_to($teh_shizznit_node, 'has');
  push @cleanup, my $r2 = $module_node->relate_to($bizzity_bomb_node, 'has');
  push @cleanup, my $r3 = $module_node->relate_to($teh_shizznit_node, 'contains');
  push @cleanup, my $r4 = $teh_shizznit_node->relate_to($variable_node,'contains');
  push @cleanup, my $r5 = $bizzity_bomb_node->relate_to($parameter_node,'contains');
  push @cleanup, my $r6 = $bizzity_bomb_node->relate_to($variable_node,'has');
  push @cleanup, my $r7 = $variable_node->relate_to($bizzity_bomb_node,'has');

  is $allowed_has_relns->validate( $r1 ), 1, 'module can have method (1)';
  is $allowed_has_relns->validate( $r2 ), 1,  'module can have method (2)';
  is $allowed_contains_relns->validate( $r3 ), 1, 'module can also contain a method';
  is $allowed_contains_relns->validate( $r4), 1, 'method can contain a variable';
  is $allowed_contains_relns->validate( $r5 ),0, 'method cannot contain a parameter';
  is $allowed_has_relns->validate( $r6 ), 0, 'method cannot "have" a variable';
  is $allowed_has_relns->validate( $r7 ), 0, 'variable cannot contain a method';

  CLEANUP : {
    for (reverse @cleanup) {
      ok $_->remove, 'entity removed from db';
    }
  }
  }


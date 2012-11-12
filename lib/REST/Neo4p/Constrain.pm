#$Id$
package REST::Neo4p::Constrain;
use base 'Exporter';
use REST::Neo4p::Constraint qw(:validate);
use REST::Neo4p::Exceptions;
use strict;
use warnings;
no warnings qw(once redefine);


BEGIN {
  $REST::Neo4p::Constrain::VERSION = '0.20';
}
our @EXPORT = qw(create_constraint drop_constraint constrain relax);
our @EXPORT_OK = qw(validate_properties validate_relationship validate_relationship_type)
our %EXPORT_TAGS = (
  validate => [@EXPORT_OK],
  auto => [@EXPORT],
  all => [@EXPORT,@EXPORT_OK]
);

our $entity_new_func = \&REST::Neo4p::Entity::new;
our $entity_set_prop_func = \&REST::Neo4p::Entity::set_property;
our $node_relate_to_func = \&REST::Neo4p::Node::relate_to;

# this class is a factory for Constraint objects

# how to constrain
# automatically constrain -- 
#  prevent the constructors from creating invalid nodes
#  prevent the constructors from creating invalid relationships
#  prevent setting invalid properties
# - raise exceptions
# validate using Constraint class methods

# building constraints
# - constructing Constraint subclass objects directly
# - factory function create_constraint()
# - load from a file (JSON, XML)

require REST::Neo4p::Entity;
require REST::Neo4p::Node;

sub create_constraint {
  my %parms = @_;
  # reqd: tag, type, constraints
  # opt: condition, rtype
  if ( @_ % 2 ) {
    REST::Neo4p::LocalException->throw("create_constraint requires a hash arg");
  }
  unless ($parms{tag}) {
    REST::Neo4p::LocalException->throw("No constraint tag defined\n");
  }
  unless ($parms{type} && grep /^$parms{type}$/,@REST::Neo4p::Constraint::CONSTRAINT_TYPES) {
    REST::Neo4p::LocalException->throw("Invalid constraint type '$parms{type}'\n");
  }
  my $ret;
  for ($parms{type}) {
    /^node_property$/ && do {
      unless (ref $parms{constraints} eq 'HASH') {
	REST::Neo4p::LocalException->throw("constraints parameter requires a hashref\n");
      }
      $parms{constraints}->{_condition} = $parms{condition} if defined $parms{condition};
      eval {
	$ret = REST::Neo4p::Constraint::NodeProperty->new(
	  $parms{tag} => $parms{constraints}
	 );
      };
      my $e;
      if ($e = REST::Neo4p::LocalException->caught()) {
	REST::Neo4p::ConstraintSpecException->throw($e->message);
      }
      if ($e = Exception::Class->caught()) {
	ref $e ? $e->rethrow : die $e;
      }
      last;
    };
    /^relationship_property$/ && do {
      unless (ref $parms{constraints} eq 'HASH') {
	REST::Neo4p::LocalException->throw("constraints parameter requires a hashref\n");
      }
      $parms{constraints}->{_condition} = $parms{condition} if defined $parms{condition};
      $parms{constraints}->{_relationship_type} = $parms{rtype} if defined $parms{rtype};
      eval {
	$ret = REST::Neo4p::Constraint::RelationshipProperty->new(
	  $parms{tag} => $parms{constraints}
	 );
      };
      my $e;
      if ($e = REST::Neo4p::LocalException->caught()) {
	REST::Neo4p::ConstraintSpecException->throw($e->message);
      }
      if ($e = Exception::Class->caught()) {
	ref $e ? $e->rethrow : die $e;
      }
      last;
    };
    /^relationship$/ && do {
      unless (ref $parms{constraints} eq 'ARRAY') {
	REST::Neo4p::LocalException->throw("constraints parameter requires an arrayref for relationship constraint\n");
      }
      eval {
	$ret = REST::Neo4p::Constraint::Relationship->new(
	  $parms{tag} => { 
	    _condition => $parms{condition},
	    _relationship_type => $parms{rtype},
	    _descriptors => $parms{constraints}
	   }
	 );
      };
      my $e;
      if ($e = REST::Neo4p::LocalException->caught()) {
	REST::Neo4p::ConstraintSpecException->throw($e->message);
      }
      if ($e = Exception::Class->caught()) {
	ref $e ? $e->rethrow : die $e;
      }
      last;
    };
    /^relationship_type$/ && do {
      unless (ref $parms{constraints} eq 'ARRAY') {
	REST::Neo4p::LocalException->throw("constraints parameter requires an arrayref for relationship type constraint\n");
      }
      eval {
	$ret = REST::Neo4p::Constraint::RelationshipType->new(
	  $parms{tag} => {
	    _condition => $parms{condition},
	    _type_list => $parms{constraints}
	   }
	 );
      };
      my $e;
      if ($e = REST::Neo4p::LocalException->caught()) {
	REST::Neo4p::ConstraintSpecException->throw($e->message);
      }
      if ($e = Exception::Class->caught()) {
	ref $e ? $e->rethrow : die $e;
      }
      last;
    };
    do { #fallthru
      die "I shouldn't be here in create_constraint()";
    };
  }
  return $ret; # the Constraint object created
}

sub drop_constraint {
  my ($tag) = @_;
  REST::Neo4p::Constraint->drop_constraint($tag);
}

# hooks into REST::Neo4p::Entity methods
sub constrain {
  my %parms = @_;
  my $strict_types = $parms{strict_types};
  *REST::Neo4p::Entity::new =
    sub {
      my ($class,$properties) = @_;
      my ($entity_type) = $class =~ /.*::(.*)/;
      $entity_type = lc $entity_type;
      goto $entity_new_func if ($entity_type !~ /^node|relationship$/);

      my $addl_components = delete $properties->{_addl_components};
      $properties->{__type} = $entity_type;
      unless (validate_properties($properties)) {
	REST::Neo4p::ConstraintException->throw(
	  "Specified properties violate active constraints\n"
	 );
      }
      delete $properties->{__type};
      $properties->{_addl_components} = $addl_components;
      goto $entity_new_func;
    };

  *REST::Neo4p::Entity::set_property = sub {
    my ($self, $props) = @_;
    REST::Neo4p::LocalException->throw("Arg must be a hashref\n") 
	unless ref($props) && ref $props eq 'HASH';
    my $entity_type = ref $self;
    $entity_type =~ s/.*::(.*)/\L$1\E/;
    my $orig_props = $self->get_properties;
    for (keys %$props) {
      $orig_props->{$_} = $props->{$_};
    }
    if ($entity_type eq 'relationship') {
      $orig_props->{_relationship_type} = $self->type;
    }
    unless (validate_properties($orig_props)) {
      REST::Neo4p::ConstraintException->throw(
	message => "Specified properties would violate active constraints\n",
	args => [@_]
       );
    }
    goto $entity_set_prop_func;
  };

  *REST::Neo4p::Node::relate_to = sub {
    my ($n1, $n2, $reln_type, $reln_props) = @_;
    unless (validate_relationship_type($reln_type) || !$strict_types) {
      REST::Neo4p::ConstraintException->throw(
	message => "Relationship type '$reln_type' is not allowed by active constraints\n",
	args => [@_]
       );
    }
    unless (validate_relationship($n1,$n2,$reln_type)) {
      REST::Neo4p::ConstraintException->throw(
	message => "Relationship violates active relationship constraints\n",
	args => [@_]
       );
    }
    $reln_props ||= {};
    $reln_props->{__type} = 'relationship';
    $reln_props->{_relationship_type} = $reln_type;
    unless (validate_properties($reln_props)) {
      REST::Neo4p::ConstraintException->throw(
	message => "Specified relationship properties violate active constraints\n",
	args => [@_]
       );
    }
    delete $reln_props->{__type};
    delete $reln_props->{_relationship_type};
    goto $node_relate_to_func;
  };
    return 1;
}

sub relax {
  *REST::Neo4p::Entity::new = $entity_new_func;
  *REST::Neo4p::Entity::set_property = $entity_set_prop_func;
  *REST::Neo4p::Node::relate_to = $node_relate_to_func;
  return 1;
}

=head1 NAME

REST::Neo4p::Constrain - Create and apply Neo4j app-level constraints

=head1 SYNOPSIS

=head1 DESCRIPTION

L<Neo4j|http://www.neo4j.org>, as a NoSQL database, is intentionally
lenient. One of the only hardwired constraints is its refusal to
remove a Node that is involved in a relationship. Other constraints to
database content (properties and their values, "kinds" of
relationships, and relationship types) must be applied at the
application level.

L<REST::Neo4p::Constrain> and L<REST::Neo4p::Constraint> attempt to
provide a flexible framework for creating and enforcing Neo4j content
constraints for applications using L<REST::Neo4p>.

The use case that inspired these modules is the following: You start
out with a set of well categorized things, that have some well defined
relationships. Each thing will be represented as a node, that's
fine. But you want to guarantee (to your client, for example) that

=over

=item * you can classify every node you add or read unambiguously into
a well-defined group;

=item * you never relate two nodes belonging to particular groups in a
way that doesn't make sense according to your well-defined
relationships.

=back

This set of modules allows you to create a set of constraints on node
and relationship properties, relationships themselves, and
relationship types to meet this use case and others. It is flexible,
in that you can choose the level at which the validation is applied:

=over

=item * You can make L<REST::Neo4p> throw exceptions when registered
constraints are violated before object creation/database insertion or
updating;

=item * You can validate properties and relationships using methods in
the code;

=item * You can check the validity of L<Node|REST::Neo4p::Node> or
L<Relationship|REST::Neo4p::Relationship> objects as retrieved from
the database

=back

L<Below|/An Example> is an example.

=head2 Types of Constraints

L<REST::Neo4p::Constrain> handles four types of constraints.

=over

=item * Node property constraints

A node property constraint specifies the presence/absence of
properties, and can specify the allowable values a property must (or
must not) take.

=item * Relationship property constraints

A relationship property constraint specifies the presence/absence of
properties, and can specifiy the allowable values a property must (or
must not) take. In addition, a relationship property constraint can be
linked to a given relationship type, so that, e.g., the creation of a
relationship of a given type can be forced to have specified
relationship properties.

=item * Relationship constraints

A relationship constraint specifies which "kinds" of nodes can
participate in a relationship of a given type. A node's "kind" is
determined by what node property constraint its properties satisfy.

=item * Relationship type constraints

A relationship type constraint simply enumerates the allowable (or
disallowed) relationship types.

=back

=head2 Specifying Constraints

L<REST::Neo4p::Constrain> exports C<create_constraint()>, which
creates and registers the different constraint types. (It also returns
the L<REST::Neo4p::Constraint> object so created, which can be
useful.)

C<create_constraint> accepts a hash of parameters. The following are required:

 create_constraint(
  tag => $tag, # a (preferably) simple and meaningful alias for this
               # constraint
  type => $type, # node_property|relationship_property|
                 # relationship|relationship_type

  constraints => $constraints, # a reference that depends on the
                             # constraint type, see below
 );

Other parameters and the form of the constraint values depend on the
constraint type:

=over

=item * Node property 

The constraints are specified as a hashref whose keys are the property
names and values are the constraints on the property values.

 constraints => {
    prop_1 => '' # property must be present, may have any value
    prop_2 => 'value', # property must be present, and value must eq 'value'
    prop_3 => qr/.alue/, # property must be present, and value must match qr/.alue/,
    prop_4 => [] # property may be present, and may have any value
    prop_5 => [<string|regexp>] # property may be present, if present
                                # value must match the given condition
    prop_6 => qr/^value1|value2|value3$/ # (use regexps for enumerations)
 }

A C<condition> parameter can be specified:

 condition => 'all' # all the specified constraints must be met, and other
                    # properties not in the constraint list may be
                    # added freely
 condition => 'only' # all the specified constraint must be met, and no other
                     # properties may be added
 condition => 'none' # reject if any of the specified constraints is
                     # satisfied ('blacklist')

C<condition> defaults to 'all'.

=item * Relationship property

Constraints on properties are specified as for node properties above.

A relationship type can be associated with the relationship property
constraint with the parameter C<rtype>:

 rtype => $relationship_type # any relationship type name, or '*' for all types

The C<condition> parameter works as for node properties above.

=item * Relationship

The basic constraint on a relationship is specified as a hashref that
maps a "kind" of from-node to a "kind" of to-node. The "kind" of node
is indicated by the tag of the node property constraint it satisfies.

The C<constraints> parameter takes an arrayref of these one-row hashrefs.

The C<rtype> parameter specifies the relationship type to which the
constraint applies.

Here's an example. Create the following node property constraints:

 create_constraint(
  tag => 'owner',
  type => 'node_property',
  constraints => {
    name => qr/a-z/i,
    species => 'human'
  }
 );

 create_constraint(
  tag => 'pet',
  type => 'node_property',
  constraints => {
    name => qr/a-z/i,
    species => qr/^dog|cat|ferret|mole rat|platypus$/
  }
 );

Then a relationship constraint that specifies owners can own pets is

 create_constraint(
  tag => 'owners2pets',
  type => 'relationship',
  rtype => 'OWNS',
  constraints =>  [{ owner => 'pet' }] # note arrayref
 );

In L<REST::Neo4p> terms, if this constraint (and only this one) is registered,

 $fred = REST::Neo4p::Node->new( { name => 'fred', species => 'human' } );
 $fluffy = REST::Neo4p::Node->new( { name => 'fluffy', species => 'mole rat' } );

 $r1 = $fred->relate_to($fluffy, 'OWNS'); # valid
 $r2 = $fluffy->relate_to($fred, 'OWNS'); # NOT VALID, throws when
                                          # constrain() is in force

=item * Relationship type

The relationship type constraint is just an arrayref of relationship types.

 constraints => [@rel_types]

The C<condition> parameter can take the following values:

 condition => 'only' # new relationships must have one of the listed
                     # types (whitelist)

 condition => 'none' # no new relationship may have any of the listed
                     # types (blacklist)

=back

=head2 Using Constraints

L<create_constraint|/create_constraint()> registers the created
constraint so that it is included in all relevant validations.

L<drop_constraint|/drop_constraint> deregisters and removes the
constraint specified by its tag:

 drop_constraint('owner');
 drop_constraint('pet');

=head3 Automatic validation

Execute L<constrain|/constrain()> to force L<REST::Neo4p> to raise a
L<REST::Neo4p::ConstraintException|REST::Neo4p::Exceptions> whenever
the construction or modification of a Node or Relationship would
violate the registered constraints.

Executing L<relax|/relax()> causes L<REST::Neo4p> to ignore all
constraint and create and modify entities as usual.

C<constrain()> and C<relax()> can be used anywhere at any time. The
effects are global.

When C<constrain()> is in force, any new constraints created are
immediately available to the validation.

=head3 "Manual" validation

To control validation directly, use the C<:validate> export tag:

 use REST::Neo4p::Constrain qw(:validate);

This provides three functions for checking properties, relationships,
and relationship types against registered constraints. They return
true if the object or spec satisfies the current constraints and false
if it violates the current constraints. No constraint exceptions are
raised.

=head1 METHODS

=over

=item create_constraint()

=item drop_constraint()

=item constrain()

=item relax()

=item validate_properties()

=item validate_relationship()

=item validate_relationship_type()

=back

=head1 SEE ALSO

L<REST::Neo4p>, L<REST::Neo4p::Constraint>

=head1 AUTHOR

    Mark A. Jensen
    CPAN ID: MAJENSEN
    majensen -at- cpan -dot- org

=head1 LICENSE

Copyright (c) 2012 Mark A. Jensen. This program is free software; you
can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

1;

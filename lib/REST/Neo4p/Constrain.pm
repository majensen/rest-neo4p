#$Id$
package REST::Neo4p::Constrain;
use base 'Exporter';
use REST::Neo4p::Constraint qw(:validate);
use REST::Neo4p::Exceptions;
use strict;
use warnings;
no warnings qw(once redefine);


BEGIN {
  $REST::Neo4p::Constrain::VERSION = '0.13';
}
our @EXPORT = qw(create_constraint constrain relax);

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

L<REST::Neo4p::Constrain> handled four types of constraints.

=over

=item * Node property constraints

A node property constraint specifies the presence/absence of
properties, and can specifiy the allowable values a property must (or
must not) take.

=item * Relationship property constraints

A relationship property constraint specifies the presence/absence of
properties, and can specifiy the allowable values a property must (or
must not) take. In addition, a relationship property constraint can be
linked to a given relationship type, so that, e.g., the creation of a
relationship of a given type can be forced to have specified properties.

=item * Relationship constraints

A relationship constraint specifies which "kinds" of nodes can
participate in a relationship of a given type. A node's "kind" is
determined by what node property constraint its properties satisfy.

=item * Relationship type constraints

A relationship type constraint simply enumerates the allowable (or
disallowed) relationship types.

=back

=head2 Specifying Constraints



=head2 Using Constraints

=head1 METHODS

=over

=item create_constraint()

=item constrain()

=item relax()

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

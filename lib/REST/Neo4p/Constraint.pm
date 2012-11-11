#$Id$
package REST::Neo4p::Constraint;
use REST::Neo4p;
use REST::Neo4p::Exceptions;
use REST::Neo4p::Constraint::Property;
use REST::Neo4p::Constraint::Relationship;
use REST::Neo4p::Constraint::RelationshipType;

use Scalar::Util qw(looks_like_number);
use strict;
use warnings;

BEGIN {
  $REST::Neo4p::Constraint::VERSION = 1.3;
}

# valid constraint types
my @CONSTRAINT_TYPES = qw( node_property relationship_property
			   relationship_type relationship );
our $CONSTRAINT_TABLE = {};

# flag - when set, use the database to store constraints
$REST::Neo4p::Constraint::USE_NEO4J = 0;

sub new {
  my $class = shift;
  my ($tag, $constraints) = @_;
  my $self = bless {}, $class;
  unless (defined $tag) {
    REST::Neo4p::LocalException->throw("New constraint requires tag as arg 1\n");
  }
  unless ($tag =~ /^[a-z0-9_.]+$/i) {
    REST::Neo4p::LocalException->throw("Constraint tag may contain only alphanumerics chars, underscore and period\n");
  }
  if ( !grep /^$tag$/,keys %$CONSTRAINT_TABLE ) {
    $CONSTRAINT_TABLE->{$tag} = $self;
    $self->{_tag} = $tag;
    $self->{_priority} = 0;
  }
  else {
    REST::Neo4p::LocalException->throw("Constraint with tag '$tag' is already defined\n");
  }
  return $self->new_from_constraint_hash($constraints);
}

sub new_from_constraint_hash {
  REST::Neo4p::AbstractMethodException->throw("Cannot call new_from_constraint_hash() from the Constraint parent class\n");
}

sub tag { shift->{_tag} }
sub type { shift->{_type} }
sub condition { shift->{_condition} }
sub priority { shift->{_priority} }
sub constraints { shift->{_constraints} }

sub set_priority {
  my $self = shift;
  my ($priority_value) = @_;
  unless (looks_like_number($priority_value)) {
    REST::Neo4p::LocalException->throw("Priority value must be numeric\n");
  }
  return $self->{_priority} = $priority_value;
}

sub get_constraint {
  my $class = shift;
  if (ref $class) {
    REST::Neo4p::ClassOnlyException->throw("get_constraint is a class method only\n");
  }
  my ($tag) = @_;
  return $CONSTRAINT_TABLE->{$tag};
}

sub drop_constraint {
  my $class = shift;
  if (ref $class) {
    REST::Neo4p::ClassOnlyException->throw("get_constraint is a class method only\n");
  }
  my ($tag) = @_;
  return delete $CONSTRAINT_TABLE->{$tag};
}

sub add_constraint {
  REST::Neo4p::AbstractMethodException->throw("Cannot call add_constraint() from the Constraint parent class\n");
}

sub remove_constraint {
  REST::Neo4p::AbstractMethodException->throw("Cannot call remove_constraint() from the Constraint parent class\n");
}

sub set_condition {
  REST::Neo4p::AbstractMethodException->throw("Cannot call set_condition() from the Constraint parent class\n");
}

# return the first property constraint according to priority
# that the property hash arg satisfies, or false if no match

sub validate_properties {
  my $class = shift;
  my ($properties) = @_;
  return unless defined $properties;
  if (ref $class) {
    REST::Neo4p::ClassOnlyException->throw("validate_properties() is a class-only method\n");
  }

  unless ( (ref($properties) =~ /Neo4p::(Node|Relationship)$/) ||
	     (ref($properties) eq 'HASH') ) {
    REST::Neo4p::LocalException->throw("Arg to validate_properties() must be a hashref, a Node object, or a Relationship object");
  }
  my $type = (ref($properties) =~ /Neo4p/) ? $properties->entity_type : '';
  my @prop_constraints = grep { $_->type =~ /${type}_property$/ } values %$CONSTRAINT_TABLE;
  @prop_constraints = sort {$a->priority <=> $b->priority} @prop_constraints;
  my $ret;
  foreach (@prop_constraints) {
    if ($_->validate($properties)) {
      $ret = $_;
      last;
    }
  }
  return $ret;
}

sub validate_relationship {
  my $class = shift;
  my ($from, $to, $reln_type) = @_;
  my ($reln) = @_;
  if (ref $class) {
    REST::Neo4p::ClassOnlyException->throw("validate_relationship() is a class-only method\n");
  }
  return unless defined $from;
  unless ( (ref($reln) =~ /Neo4p::Relationship$/) || 
	   ( (ref($from) eq 'HASH') && (ref($to) eq 'HASH') &&
	       defined $reln_type ) ) {
    REST::Neo4p::LocalException->throw("validate_relationship() requires a Relationship object, or two property hashrefs followed by a relationship type\n");
  }
  my @reln_constraints = grep {$_->type eq 'relationship'} values %$CONSTRAINT_TABLE;
  @reln_constraints = sort {$a->priority <=> $b->priority} @reln_constraints;
  my $ret;
  foreach (@reln_constraints) {
    if ($_->validate($from => $to, $reln_type)) {
      $ret = $_;
      last;
    }
  }
  return $ret;
}

sub validate_relationship_type {
  my $class = shift;
  my ($reln_type) = @_;
  if (ref $class) {
    REST::Neo4p::ClassOnlyException->throw("validate_relationhip_type() is a class-only method\n");
  }
  return unless defined $reln_type;
  my @type_constraints = grep {$_->type eq 'relationship_type'} values %$CONSTRAINT_TABLE;
  @type_constraints = sort {$a->priority <=> $b->priority} @type_constraints;
  my $ret;
  foreach (@type_constraints) {
    if ($_->validate($reln_type)) {
      $ret = $_;
      last;
    }
  }
  return $ret;
}

=head1 NAME

REST::Neo4p::Constraint - Application-level Neo4j Constraints

=head1 SYNOPSIS

=head1 DESCRIPTION

C<REST::Neo4p::Constraint> 

Create the following constraints

=over

=item Constrain node properties

=item Constrain relationship properties

=item Constrain relationship types

=item Constrain relationships between nodes

=back

=head2 Representing Constraints

store constraints in the neo4j database if desired

read/write as json 

constrain nodes to property constraint sets

constrain nodes to property sets according to a given property's value
(or sets of properties/values)

constrain relationships to property sets

constrain property values

constrain created relationships to those of certain types

constrain relationships of a certain types to certain property sets

constrain participation of nodes of given properties/values in relationships
of given types

constrain direction of relationships of given types from and to nodes of 
given properties/values


property set tags

"property constraint set"

{ constraint_tag => 
 {
  constraint_type => 'node_property' | 'relationship_property',
  constraints =>
  { 
    _condition => constraint_conditions, # ('all'|'only'|'none')
    prop_0 => [] # may have, no constraint
    prop_1 => [<string|regexp>] # may have, if present must meet 
    prop_2 => '' # must have, no constraint
    prop_3 => 'value', # must have, value must eq 'value'
    prop_4 => qr/.alue/, # must have, value must match qr/.alue/,
    prop_5 => qr/^value1|value2|value3$/
      (use regexps for enumerations)

  }
}

"relationship type constraint"

{relationship_type_constraint_tag => 
 {
  constraint_type => "relationship_type",
  constraints =>
  {
   _condition => constraint_conditions, # ('only'|'none')
    type_list => [ 'type_name_1', 'type_name_2', ...]
  }
 }
}

"relationship constraint"

{ relationship_constraint_tag =>
 {
  constraint_type => "relationship",
 
  constraints =>
  { _condition => (only|none),
    _relationship_type => <relationship_typename>,
    _descriptors => [{ constraint_tag => constraint_tag },...] }
 }
}

must meet at least these conditions - checklist - all
must meet only these conditions - whitelist - only (cannot possess 
 properties not enumerated)
must not meet any conditions - blacklist - none


apply at entity construction
apply at property add
apply at property change

method to instruct contraints not to be applied for a given operation

method to scan a set of entities against set of constraints (validation)

activate constraints
suspend constraints
resume constraints
clear constraints

=head1 METHODS

=over

=item new()

=item load_constraints()

=item get_constraint() (class method)

=item add_constraint()

=item remove_constraint()

=item tag()

=item type()

=item condition()

=item constraints()

=item priority()

=item type_list()

=item add_relationship_types()

=item set_condition()

 Set/get 'all', 'only', 'none' for a given constraint

=item set_priority()

 constraints with higher priority will be checked before constraints with 
 lower priority

=item validate_properties()

=item validate_relationship()

=item validate_relationship_type()

Returns the registered constraint object with the highest priority that
the argument satisfies, or false if none is satisfied.

These are class-only methods. Constraint objects are registered when they
are constructed.

=head1 SEE ALSO

L<REST::Neo4p>, L<REST::Neo4p::Node>, L<REST::Neo4p::Relationship>,
L<REST::Neo4p::Constraint::Property>, L<REST::Neo4p::Constraint::Relationship>,
L<REST::Neo4p::Constraint::RelationshipType>.

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

#$Id$
package REST::Neo4p::Constraint;
use base 'Exporter';
use REST::Neo4p;
use REST::Neo4p::Exceptions;
use REST::Neo4p::Constraint::Property;
use REST::Neo4p::Constraint::Relationship;
use REST::Neo4p::Constraint::RelationshipType;

use Scalar::Util qw(looks_like_number);
use strict;
use warnings;

our @EXPORT_OK = qw( validate_properties validate_relationship validate_relationship_type );
our %EXPORT_TAGS = ( validate => [qw(validate_properties validate_relationship validate_relationship_type)] );

BEGIN {
  $REST::Neo4p::Constraint::VERSION = "0.20";
}

# valid constraint types
our @CONSTRAINT_TYPES = qw( node_property relationship_property
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
#  my $class = shift;
  # Exported
  my ($properties) = @_;
  return unless defined $properties;
  # if (ref $class) {
  #   REST::Neo4p::ClassOnlyException->throw("validate_properties() is a class-only method\n");
  # }

  unless ( (ref($properties) =~ /Neo4p::(Node|Relationship)$/) ||
	     (ref($properties) eq 'HASH') ) {
    REST::Neo4p::LocalException->throw("Arg to validate_properties() must be a hashref, a Node object, or a Relationship object");
  }
  my $type = (ref($properties) =~ /Neo4p/) ? $properties->entity_type : 
    (delete $properties->{__type} || '');
  my @prop_constraints = grep { $_->type =~ /${type}_property$/ } values %$CONSTRAINT_TABLE;
  @prop_constraints = sort {$b->priority <=> $a->priority} @prop_constraints;
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
#  my $class = shift;
  # Exported
  my ($from, $to, $reln_type) = @_;
  my ($reln) = @_;
  # if (ref $class) {
  #   REST::Neo4p::ClassOnlyException->throw("validate_relationship() is a class-only method\n");
  # }
  return unless defined $from;
  unless ( (ref($reln) =~ /Neo4p::Relationship$/) || 
	   ( (ref($from) =~ /Neo4p::Node|HASH$/) && (ref($to) =~ /Neo4p::Node|HASH$/) &&
	       defined $reln_type ) ) {
    REST::Neo4p::LocalException->throw("validate_relationship() requires a Relationship object, or two property hashrefs or nodes followed by a relationship type\n");
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
#  my $class = shift;
  # Exported
  my ($reln_type) = @_;
  # if (ref $class) {
  #   REST::Neo4p::ClassOnlyException->throw("validate_relationhip_type() is a class-only method\n");
  # }
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

See L<REST::Neo4p::Constraint::Property>, L<REST::Neo4p::Constraint::Relationship>, L<REST::Neo4p::Constraint::RelationshipType> for examples.

=head1 DESCRIPTION

Objects of class REST::Neo4p::Constraint are used to capture and
organize L<REST::Neo4p> application level constraints on Neo4j Node
and Relationship content.

The L<REST::Neo4p::Constrain> module provides a more convenient
factory for REST::Neo4p::Constraint subclasses that specify L<node
property|REST::Neo4p::Constraint::Property>, L<relationship
property|REST::Neo4p::Property>,
L<relationship|REST::Neo4p::Constraint::Relationship>, and
L<relationship type|REST::Neo4p::Constraint::RelationshipType>
constraints.

=head1 METHODS

=head2 Class Methods

=over

=item new()

 $reln_pc = REST::Neo4p::Constraint::RelationshipProperty->new($constraints);

Constructor.  Construction also registers the constraint for
validation. See subclass pod for details.

=item get_constraint()
 
 $c = REST::Neo4p::Constraint->get_constraint('spiffy_node');

Get a registered constraint by constraint tag. Returns false if none found.

=back 

=head2 Instance Methods

=over

=item tag()

=item type()

=item condition()

=item priority()

=item constraints()

Getters for object fields.

=item set_condition()

 $reln_c->set_condition('only');

Set the group condition for the constraint. See subclass pod for details.

=item set_priority()

 $node_pc->set_priority(10);

Set the constraint's priority. Constraints with higher priority will
be checked before constraints with lower priority in the
L<validate_*()|/Functional interface for validation> functions.

=item add_constraint()

 $node_pc->add_constraint( 'warning_level' => qr/^[0-9]$/ );
 $reln_c->add_constraint( { 'species' => 'genus' } );

Add an individual constraint specification to an existing constraint object. See subclass pod for details.

=item remove_constraint()

 $node_pc->remove_constraint( 'warning_level' );
 $reln_c->remove_constraint( { 'genus' => 'species' } );

Remove an individual constraint specification from an existing constraint object. See subclass pod for details.

=back

=head2 Functional interface for validation

=over

=item validate_properties()

=item validate_relationship()

=item validate_relationship_type()

Functional interface. Returns the registered constraint object with
the highest priority that the argument satisfies, or false if none is
satisfied.

These methods can be exported as follows:

 use REST::Neo4p::Constraint qw(:validate)

They can also be exported from L<REST::Neo4p::Constrain>:

 use REST::Neo4p::Constrain qw(:validate)

=back

=head1 SEE ALSO

L<REST::Neo4p>,L<REST::Neo4p::Constrain>,
L<REST::Neo4p::Constraint::Property>, L<REST::Neo4p::Constraint::Relationship>,
L<REST::Neo4p::Constraint::RelationshipType>. L<REST::Neo4p::Node>, L<REST::Neo4p::Relationship>,

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

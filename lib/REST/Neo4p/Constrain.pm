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
    unless (validate_relationship_type($reln_type)) {
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

=head1 METHODS

=over

=item create_constraint()

=item constrain()

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

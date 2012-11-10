#$Id$
package REST::Neo4p::Constraint::RelationshipType;
use base 'REST::Neo4p::Constraint';
use strict;
use warnings;

BEGIN {
  $REST::Neo4p::Constraint::RelationshipType::VERSION = 0.13;
}

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  $self->{_type} = 'relationship_type';
  return $self;
}

sub new_from_constraint_hash {
  my $self = shift;
  my ($constraints) = @_;
  die "tag not defined" unless $self->tag;
  die "constraint hash not defined or not a hashref" unless defined $constraints && (ref $constraints eq 'HASH');
  if (my $cond = $constraints->{_condition}) {
    unless (grep(/^$cond$/,qw( only none ))) {
      die "Relationship type constraint condition must be one of (only|none)";
    }
    $self->{_condition} = delete $constraints->{_condition};
  }
  else {
    $self->{_condition} = 'only'; # default
  }
  unless ( defined $constraints->{_type_list} &&
	   ref $constraints->{_type_list} eq 'ARRAY' ) {
    die "Relationship type constraint must contain an arrayref of types"
  }
  $self->{_type_list} = delete $constraints->{_type_list};
  $self->{_constraints} = $constraints;
  return $self;
}

sub add_constraint {
  my $self = shift;
  my ($key, $value) = @_;
  return $self->add_types(@_);
}

sub add_types {
  my $self = shift;
  my @types = @_;
  $self->{_type_list} ||= [];
  for (@types) {
    if (ref) {
      REST::Neo4p::LocalException->throw("Relationship types must be strings\n");
    }
    push @{$self->{_type_list}}, $_;
  }
  return 1;
}

sub type_list {
  my $self = shift;
  return @{$self->{_type_list}} if (defined $self->{_type_list});
  return;
}

sub remove_constraint { shift->remove_type(@_) }

sub remove_type {
  my $self = shift;
  my ($tag) = @_;
  my $ret;
  return unless $self->type_list;
  for my $i (0..$#{$self->{_type_list}}) {
    if ($tag eq $self->{_type_list}->{$i}) {
      $ret = delete $self->{_type_list}->{$i};
      last;
    }
  }
  return $ret;
}

sub set_condition {
  my $self = shift;
  my ($condition) = @_;
  unless ($condition =~ /^(only|none)$/) {
    REST::Neo4p::LocalException->throw("Relationship type condition must be one of (only|none)\n");
  }
  return $self->{_condition} = $condition;
}

sub validate {
  my $self = shift;
  my ($type) = (@_);
  return unless defined $type;
  $type = $type->type if (ref $type =~ /Neo4p::Relationship$/);
}
=head1 NAME

REST::Neo4p::Constraint::RelationshipType - Neo4j Relationship Type Constraints

=head1 SYNOPSIS

=head1 DESCRIPTION

constrain relationship types 

"relationship type constraint"

{relationship_type_constraint_tag => 
 {
  constraint_type => "relationship_type",
  constraints =>
  {
   _condition => constraint_conditions, # ('only'|'none')
   _type_list => [ 'type_name_1', 'type_name_2', ...]
  }
 }
}

must meet only these conditions - whitelist - only (cannot match unless matching type is enumerated)
must not meet any conditions - blacklist - none

=head1 METHODS

=over

=item new()

=item add_constraint()

=item add_types()

=item remove_constraint()

=item remove_type()

=item tag()

=item rtype()

The relationship type to which this constraint applies.

=item type()

=item condition()

=item constraints()

=item priority()

=item set_condition()

 Set/get 'all', 'only', 'none' for a given constraint

=item set_priority()

 constraints with higher priority will be checked before constraints with 
 lower priority

=item validate()

 true if the item meets the constraint, false if not

=head1 SEE ALSO

L<REST::Neo4p>, L<REST::Neo4p::Node>, L<REST::Neo4p::Relationship>,
L<REST::Neo4p::Constraint>, L<REST::Neo4p::Constraint::Relationship>,
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

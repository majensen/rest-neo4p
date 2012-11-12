#$Id$
package REST::Neo4p::Constraint::Relationship;
use base 'REST::Neo4p::Constraint';
use strict;
use warnings;

BEGIN {
  $REST::Neo4p::Constraint::Relationship::VERSION = '0.13';
}

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  $self->{_type} = 'relationship';
  return $self;

}

sub new_from_constraint_hash {
  my $self = shift;
  my ($constraints) = @_;
  die "tag not defined" unless $self->tag;
  die "constraint hash not defined or not a hashref" unless defined $constraints && (ref $constraints eq 'HASH');
  if (my $cond = $constraints->{_condition}) {
    unless (grep(/^$cond$/,qw( only none ))) {
      die "Relationship constraint condition must be only|none";
    }
  }

  $self->{_condition} = delete $constraints->{_condition} || 'only';
  $self->{_relationship_type} = delete $constraints->{_relationship_type};
  unless (ref $constraints->{_descriptors} eq 'ARRAY') {
    die "relationship constraint descriptors must be array of hashrefs";
  }
  foreach (@{$constraints->{_descriptors}}) {
    unless (ref eq 'HASH') {
      die "relationship constraint descriptor must by a hashref";
    }
  }
  $self->{_constraints} = $constraints;
  return $self;
}

sub rtype { shift->{_relationship_type} }

sub add_constraint {
  my $self = shift;
  my ($value) = @_;
  return unless defined $value;
  unless (ref($value) eq 'HASH') {
    REST::Neo4p::LocalException->throw("Relationship descriptor must be a hashref { node_property_constraint_tag => node_property_constraint_tag }\n");
  }
  $self->constraints->{_descriptors} ||= [];
  while ( my ($tag1, $tag2) = each %$value ) {
    unless ( grep(/^$tag1$/, keys %$REST::Neo4p::Constraint::CONSTRAINT_TABLE) ) {
      REST::Neo4p::LocalException->throw("Constraint '$tag1' is not defined\n");
    }
    unless ( grep(/^$tag2$/, keys %$REST::Neo4p::Constraint::CONSTRAINT_TABLE) ) {
      REST::Neo4p::LocalException->throw("Constraint '$tag2' is not defined\n");
    }
    push @{$self->constraints->{_descriptors}}, $value;
  }
  return 1;
}

sub remove_constraint {
  my $self = shift;
  my ($from, $to) = @_;
  my $ret;
  my $descr = $self->constraints->{_descriptors};
  for my $i (0..$#{$descr}) {
    my ($k, $v) = each %{$descr->[$i]};
    if ( ($k eq $from) && ( $v eq $to ) ) {
      $ret = delete $descr->[$i];
      last;
    }
  }
  return $ret;
}

sub set_condition {
  my $self = shift;
  my ($condition) = @_;
  unless ($condition =~ /^(only|none)$/) {
    REST::Neo4p::LocalException->throw("Relationship condition must be one of (only|none)\n");
  }
  return $self->{_condition} = $condition;
}

sub validate {
  my $self = shift;
  my ($from, $to, $reln_type) = @_;
  my ($reln) = @_;
  return unless defined $from;
  if (ref($reln) =~ /Neo4p::Relationship$/) {
    $from = $reln->start_node->get_properties;
    $to = $reln->end_node->get_properties;
    $reln_type = $reln->type;
  }
  REST::Neo4p::LocalException->throw("Relationship type (arg3) must be provided to validate") unless defined $reln_type;
  # first check if relationship type is defined and
  # is represented in this constraint
  # if validation is strict, fail if type undefined or not found
  # if validation is lax, continue

  unless ((ref($from) =~ /Neo4p::Node|HASH$/) &&
	  (ref($to) =~ /Neo4p::Node|HASH$/)) {
    REST::Neo4p::LocalException->throw("validate() requires a pair of Node objects, a pair of hashrefs, or a single Relationship object\n");
  }

  return 0 unless (($self->rtype eq '*') || ($reln_type eq $self->rtype));
  return 1 if ( ($self->condition eq 'none') && !defined $self->constraints->{$reln_type} ); 

  my @descriptors = @{$self->constraints->{_descriptors}};
  $from = $from->get_properties if ref($from) =~ /Neo4p::Node$/;
  $to = $to->get_properties if ref($to) =~ /Neo4p::Node$/;
  # $to, $from now normalized to property hashrefs

  my $from_constraint = REST::Neo4p::Constraint::validate_properties($from);
  my $to_constraint = REST::Neo4p::Constraint::validate_properties($to);

  $from_constraint = $from_constraint && $from_constraint->tag;
  $to_constraint = $to_constraint && $to_constraint->tag;
  # $to_constraint, $from_constraint contain undef or the matching 
  # constraint tag

  # filter @descriptors based on $from_constraint tag
  $to_constraint ||= '*';
  $from_constraint ||= '*';
  @descriptors = grep { defined $_->{ $from_constraint } } @descriptors;

  if (@descriptors) {
    my $found = grep /^\Q$to_constraint\E$/, map {$_->{$from_constraint}} @descriptors;
    return ($self->condition eq 'only') ? $found : !$found;
  }
  else {
    return ($self->condition eq 'only') ? 0 : 1;
  }
}

=head1 NAME

REST::Neo4p::Constraint::Relationship - Neo4j Relationship Constraints

=head1 SYNOPSIS

=head1 DESCRIPTION

"relationship constraint"

{ <relationship_constraint_tag> =>
 {
  constraint_type => "relationship",
  constraints =>
  { _condition => (only|none),
    _relationship_type => <relationship_typename>,
    _descriptors => [{ property_constraint_tag => property_constraint_tag },...] }
 }
}

must meet only these conditions - whitelist - only (cannot match unless matching descriptor is enumerated)
must not meet any conditions - blacklist - none

=head1 METHODS

=over

=item new()

=item add_constraint()

=item remove_constraint()

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

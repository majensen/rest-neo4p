#$Id$
package REST::Neo4p::Constraint::Relationship;
use base 'REST::Neo4p::Constraint';
use strict;
use warnings;

BEGIN {
  $REST::Neo4p::Constraint::Relationship::VERSION = 0.129;
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
      die "Property constraint condition must be only|none";
    }
    $self->{_condition} = delete $constraints->{_condition};
  }
  else {
    $self->{_condition} = 'only';
  }
  while ( my ($rel_type,$rel_array) = each %$constraints) {
    unless (ref $rel_array eq 'ARRAY') {
      die "relationship constraint for type '$rel_type' must be array of hashrefs";
    }
    foreach (@$rel_array) {
      unless (ref eq 'HASH') {
	die "relationship constraint for type '$rel_type' must be array of hashrefs (2)";
      }
    }
  }
  $self->{_constraints} = $constraints;
  return $self;
}
sub add_constraint {
  my $self = shift;
  my ($key, $value) = @_;
  unless (!ref($key) && ($key=~/^[a-z0-9_]+$/i)) {
    REST::Neo4p::LocalException->throw("Relationship type name (arg 1) contains disallowed characters in add_constraint\n");
  }
  unless (defined $value && (ref($value) eq 'HASH')) {
    REST::Neo4p::LocalException->throw("Relationship constraint for type '$key' must be a hashref { node_property_constraint_tag => node_property_constraint_tag }\n");
  }
  $self->constraints->{$key} ||= [];
  while ( my ($tag1, $tag2) = each %$value ) {
    unless ( grep(/^$tag1$/, keys %$REST::Neo4p::Constraint::CONSTRAINT_TABLE) ) {
      REST::Neo4p::LocalException->throw("Constraint '$tag1' is not defined\n");
    }
    unless ( grep(/^$tag2$/, keys %$REST::Neo4p::Constraint::CONSTRAINT_TABLE) ) {
      REST::Neo4p::LocalException->throw("Constraint '$tag2' is not defined\n");
    }
    push @{$self->constraints->{$key}}, $value;
  }
  return 1;
}

sub remove_constraint {
  my $self = shift;
  my ($tag) = @_;
  delete $self->constraints->{$tag};
}

sub set_condition {
  REST::Neo4p::NotSuppException->throw("Relationship constraints do not accept a condition\n");
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

  return 1 if ( ($self->condition eq 'none') && !defined $self->constraints->{$reln_type} ); 

  my @conditions = @{$self->constraints->{$reln_type}};
  $from = $_->get_properties if ref($from) =~ /Neo4p::Node$/;
  $to = $_->get_properties if ref($to) =~ /Neo4p::Node$/;
  # $to, $from now normalized to property hashrefs

  my $from_constraint = REST::Neo4p::Constraint->validate_properties($from);
  my $to_constraint = REST::Neo4p::Constraint->validate_properties($to);

  $from_constraint = $from_constraint && $from_constraint->tag;
  $to_constraint = $to_constraint && $to_constraint->tag;
  # $to_constraint, $from_constraint contain undef or the matching 
  # constraint tag

  # filter @conditions based on $from_constraint tag
  $to_constraint ||= '*';
  $from_constraint ||= '*';
  @conditions = grep { defined $_->{ $from_constraint } } @conditions;

  if (@conditions) {
    my $found = grep /^\Q$to_constraint\E$/, map {$_->{$from_constraint}} @conditions;
    return ($self->condition eq 'only') ? $found : !$found;
  }
  else {
    return ($self->condition eq 'only') ? 0 : 1;
  }
}

1;

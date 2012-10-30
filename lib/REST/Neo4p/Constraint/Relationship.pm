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
  my ($to, $from) = @_;
  my ($reln) = @_;
  return unless defined $to;
  if (ref($reln) =~ /Relationship$/) {
    $to = $reln->start_node;
    $from = $reln->end_node;
  }
  unless ((ref($to) =~ /Node|HASH$/) &&
	  (ref($from) =~ /Node|HASH$/)) {
    REST::Neo4p::LocalException->throw("validate() requires a pair of Node objects, a pair of hashrefs, or a single Relationship object\n");
  }

  for (ref $item) {
    /HASH/ && do {
      last;
    };
    /REST::Neo4p::Relationship/ && do {
      last;
    };
  }
}

1;

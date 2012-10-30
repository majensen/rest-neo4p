#$Id$
package REST::Neo4p::Constraint::RelationshipType;
use base 'REST::Neo4p::Constraint';
use strict;
use warnings;

BEGIN {
  $REST::Neo4p::Constraint::RelationshipType::VERSION = 0.129;
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
      die "Relationship type constraint condition must be only|none";
    }
    $self->{_condition} = delete $constraints->{_condition};
  }
  else {
    $self->{_condition} = 'only'; # default
  }
  unless ( defined $constraints->{type_list} &&
	   ref $constraints->{type_list} eq 'ARRAY' ) {
    die "Relationship type constraint must contain an arrayref of types"
  }
  $self->{_type_list} = $constraints->{type_list};
  $self->{_constraints} = $constraints;
  return $self;
}

sub add_constraint {
  my $self = shift;
  my ($key, $value) = @_;
  return $self->add_relationship_types(@_);
}

sub add_relationship_types {
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
  my $n = scalar $self->type_list;
  return unless $n;
  for (my $i=0; $i<$n; $i++) {
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
    REST::Neo4p::LocalException->throw("Relationship type condition must be one of only, none\n");
  }
  return $self->{_condition} = $condition;
}

1;

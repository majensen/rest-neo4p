#$Id$
package REST::Neo4p::Constraint::Property;
use base 'REST::Neo4p::Constraint';
use strict;
use warnings;

BEGIN {
  $REST::Neo4p::Constraint::Property::VERSION = 0.129;
}


sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
}

sub new_from_constraint_hash {
  my $self = shift;
  my ($constraints) = @_;
  die "tag not defined" unless $self->tag;
  die "constraint hash not defined or not a hashref" unless defined $constraints && (ref $constraints eq 'HASH');
  if (my $cond = $constraints->{_condition}) {
    unless (grep(/^$cond$/,qw( all only none ))) {
      die "Relationship type constraint condition must be all|only|none";
    }
    $self->{_condition} = delete $constraints->{_condition};
  }
  else {
    $self->{_condition} = 'only';
  }
  $self->{_constraints} = $constraints;
  return $self;
};
  
sub add_constraint {
  my $self = shift;
  my ($key, $value) = @_;
  unless (!ref($key) && ($key=~/^[a-z0-9_]+$/i)) {
    REST::Neo4p::LocalException->throw("Property name (arg 1) contains disallowed characters in add_constraint\n");
  }
  unless (!ref($value) || ref($value) eq 'ARRAY') {
    REST::Neo4p::LocalException->throw("Constraint value for '$key' must be string, regex, or arrayref of strings and regexes\n");
  }
  $self->constraints->{$key} = $value;
  return 1;
}

sub remove_constraint {
  my $self = shift;
  my ($tag) = @_;
  delete $self->constraints->{$tag};
}

sub set_condition {
  my $self = shift;
  my ($condition) = @_;
  unless ($condition =~ /^(all|only|none)$/) {
    REST::Neo4p::LocalException->throw("Property constraint condition must be one of all, only, none\n");
  }
  return $self->{_condition} = $condition;
}

1;

package REST::Neo4p::Constraint::NodeProperty;
use base 'REST::Neo4p::Constraint::Property';
use strict;
use warnings;

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  $self->{_type} = 'node_property';
  return $self;
}

1;

package REST::Neo4p::Constraint::RelationshipProperty;
use base 'REST::Neo4p::Constraint::Property';
use strict;
use warnings;

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  $self->{_type} = 'relationship_property';
  return $self;
}

1;

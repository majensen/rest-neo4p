#$Id$
use v5.10;
package REST::Neo4p::Schema;
use REST::Neo4p::Exceptions;
use strict;
use warnings;

BEGIN {
  $REST::Neo4p::Schema::VERSION = '0.2240';
}

#require 'REST::Neo4p';

sub new {
  REST::Neo4p::CommException->throw("Not connected\n") unless
      REST::Neo4p->connected;
  unless (REST::Neo4p->_check_version(2,0,0)) {
    REST::Neo4p::VersionMismatchException->throw("Schema indexes and constraints are not available in Neo4j server version < 2.0.0\n");
  }
  my $class = shift;
  my $self = {
    _handle => REST::Neo4p->handle,
    _agent => REST::Neo4p->agent
   };
  bless $self, $class;
}

sub _handle { shift->{_handle} }
sub _agent { shift->{_agent} }

sub create_index {
  my $self = shift;
  my ($label, @props) = @_;
  REST::Neo4p::LocalException->throw("Arg 1 must be a label and arg 2..n a property name\n") unless (defined $label && @props);
  foreach (@props) {
    my $content = { property_keys => [$_] };
    eval {
      $self->_agent->post_data([qw/schema index/,$label], $content);
    };
    if (my $e = REST::Neo4p::ConflictException->caught) {
      1; # ignore, already present
    }
    elsif ($e = Exception::Class->caught()) {
      ref $e ? $e->rethrow : die $e;
    }
  }
  return 1;
}

# get_indexes returns false if label not found
sub get_indexes {
  my $self = shift;
  my ($label) = @_;
  REST::Neo4p::LocalException->throw("Arg 1 must be a label\n") unless defined $label;
  eval {
    $self->_agent->get_data(qw/schema index/, $label);
  };
  if (my $e = REST::Neo4p::NotFoundException->caught) {
    return;
  }
  elsif ($e = Exception::Class->caught()) {
    ref $e ? $e->rethrow : die $e;
  }
  my @ret;
  foreach (@{$self->_agent->decoded_content}) {
    push @ret, $_->{property_keys}[0];
  }
  return @ret;
}

sub drop_index {
  my $self = shift;
  my ($label,$name) = @_;
  REST::Neo4p::LocalException->throw("Arg 1 must be a label and arg 2 a property name\n") unless (defined $label && defined $name);
  eval {
    $self->_agent->delete_data(qw/schema index/, $label, $name);
  };
  if (my $e = REST::Neo4p::NotFoundException->caught) {
    return;
  }
  elsif ($e = Exception::Class->caught()) {
    ref $e ? $e->rethrow : die $e;
  }
  return 1;
}

sub create_constraint {
  my $self = shift;
  my ($label, $property, $c_type) = @_;
  $c_type ||= 'uniqueness';
  REST::Neo4p::LocalException->throw("Arg 1 must be a label and arg 2..n a property name\n") unless (defined $label && @props);
  foreach (@props) {
    my $content = { property_keys => [$_] };
    eval {
      $self->_agent->post_data([qw/schema constraint/,$c_type,$label], $content);
    };
    if (my $e = REST::Neo4p::ConflictException->caught) {
      1; # ignore, already present
    }
    elsif ($e = Exception::Class->caught()) {
      ref $e ? $e->rethrow : die $e;
    }
  }
  return 1;
}

sub get_constraints {
  my $self = shift;
  my ($label, $property, $c_type) = @_;
  $c_type ||= 'uniqueness';
}

sub drop_constraint {
  my $self = shift;
  my ($label,$property,$c_type) = @_;
  $c_type ||= 'uniqueness';
}

=head1 NAME

REST::Neo4p::Schema - Label-based indexes and constraints

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=over

=item create_index()

=item get_indexes()

=item drop_index()

=item create_constraint()

=item get_constraints()

=item drop_constraint()

=back

=head1 SEE ALSO

L<REST::Neo4p>, L<REST::Neo4p::Index>, L<REST::Neo4p::Query>

=head1 AUTHOR

    Mark A. Jensen
    CPAN ID: MAJENSEN
    majensen -at- cpan -dot- org

=head1 LICENSE

Copyright (c) 2013 Mark A. Jensen. This program is free software; you
can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

1;

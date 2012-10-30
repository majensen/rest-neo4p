#$Id: Entity.pm 17684 2012-09-23 01:12:42Z jensenma $
package REST::Neo4p::Entity;
use REST::Neo4p::Exceptions;
use Carp qw(croak carp);
use JSON;
use strict;
use warnings;

# base class for nodes, relationships, indexes...
BEGIN {
  $REST::Neo4p::Entity::VERSION = '0.1283';
}

our $ENTITY_TABLE = {};

# new(\%properties)
# creates an entity in the db (with \%properties set), and returns
# a Perl object

sub new {
  my $class = shift;
  my ($entity_type) = $class =~ /.*::(.*)/;
  $entity_type = lc $entity_type;
  if ($entity_type eq 'entity') {
    REST::Neo4p::NotSuppException->throw("Cannot use ".__PACKAGE__." directly\n");
  }
  my ($properties) = (@_);
  my $url_components = delete $properties->{_addl_components};
  my $agent = $REST::Neo4p::AGENT;
  REST::Neo4p::CommException->throw("Not connected\n") unless $agent;
  my $decoded_resp;
  eval {
    $decoded_resp = $agent->post_data([$entity_type,
					$url_components ? @$url_components : ()],
				       $properties);
  };
  my $e;
  if ($e = Exception::Class->caught('REST::Neo4p::Exception')) {
    # TODO : handle cases
    $e->rethrow;
  }
  elsif ($@) {
    ref $@ ? $@->rethrow : die $@;
  }

  $decoded_resp->{self} ||= $agent->location if ref $decoded_resp;
  return ref($decoded_resp) ?
    $class->new_from_json_response($decoded_resp) :
      $class->new_from_batch_response($decoded_resp, @$url_components);
}

sub new_from_json_response {
  my $class = shift;
  my ($entity_type) = $class =~ /.*::(.*)/;
  $entity_type = lc $entity_type;
  if ($entity_type eq 'entity') {
    REST::Neo4p::NotSuppException->throw("Cannot use ".__PACKAGE__." directly\n");
  }
  my ($decoded_resp) = (@_);
  unless (defined $decoded_resp) {
    REST::Neo4p::LocalException->throw("new_from_json_response() called with undef argument\n");
  }
  unless ($ENTITY_TABLE->{$entity_type}{_actions}) {
    # capture the url suffix patterns for the entity actions:
    for (keys %$decoded_resp) {
      my ($suffix) = $decoded_resp->{$_} =~ m|.*$entity_type/[0-9]+/(.*)|;
      $ENTITY_TABLE->{$entity_type}{_actions}{$_} = $suffix;
    }
  }
  # "template" in next line is a kludge for get_indexes
  my $self_url  = $decoded_resp->{self} || $decoded_resp->{template};
  $self_url =~ s/{key}.*$//; # another kludge for get_indexes
  my ($obj) = $self_url =~ /([a-z0-9_]+)\/?$/i;
  my ($start_id,$end_id);
  if ($decoded_resp->{start}) {
    ($start_id) = $decoded_resp->{start} =~ /([0-9]+)\/?$/;
    ($end_id) = $decoded_resp->{end} =~ /([0-9]+)\/?$/;
  }
  unless (defined $ENTITY_TABLE->{$entity_type}{$obj}) {
    if ($decoded_resp->{template}) {     # another kludge for get_indexes
      ($decoded_resp->{type}) = $decoded_resp->{template} =~ m|index/([a-z]+)/|;
    }
    $ENTITY_TABLE->{$entity_type}{$obj}{entity_type} = $entity_type;
    $ENTITY_TABLE->{$entity_type}{$obj}{self} = bless \$obj, $class;
    $ENTITY_TABLE->{$entity_type}{$obj}{self_url} = $self_url;
    $ENTITY_TABLE->{$entity_type}{$obj}{start_id} = $start_id;
    $ENTITY_TABLE->{$entity_type}{$obj}{end_id} = $end_id;
    $ENTITY_TABLE->{$entity_type}{$obj}{type} = $decoded_resp->{type};
  }
  if ($REST::Neo4p::CREATE_AUTO_ACCESSORS && ($entity_type ne 'index')) {
    my $self =  $ENTITY_TABLE->{$entity_type}{$obj}{self};
    my $props = $self->get_properties;
    for (keys %$props) { $self->_create_accessors($_) unless $self->can($_); }
  }
  return $ENTITY_TABLE->{$entity_type}{$obj}{self};
}

sub new_from_batch_response {
  my $class = shift;
  my ($entity_type) = $class =~ /.*::(.*)/;
  $entity_type = lc $entity_type;
  if ($entity_type eq 'entity') {
    REST::Neo4p::NotSuppException->throw("Cannot use ".__PACKAGE__." directly\n");
  }
  my ($id_token) = (@_);
  $ENTITY_TABLE->{$entity_type}{$id_token}{entity_type} = $entity_type;
  $ENTITY_TABLE->{$entity_type}{$id_token}{self} = bless \$id_token, $class;
  $ENTITY_TABLE->{$entity_type}{$id_token}{self_url} = $id_token;
  $ENTITY_TABLE->{$entity_type}{$id_token}{batch} = 1;
  $ENTITY_TABLE->{batch_objs}->{$id_token} =  $ENTITY_TABLE->{$entity_type}{$id_token}{self};
  return $ENTITY_TABLE->{$entity_type}{$id_token}{self};
}

# remove() - delete the node and destroy the object
sub remove {
  my $self = shift;
  my @url_components = @_;
  my $entity_type = ref $self;
  $entity_type =~ s/.*::(.*)/\L$1\E/;
  my $agent = $REST::Neo4p::AGENT;
  eval {
    $agent->delete_data($entity_type, @url_components, $$self);
  };
  my $e;
  if ($e = Exception::Class->caught('REST::Neo4p::NotFoundException')) {
    1;
  }
  elsif ($@) {
    ref $@ ? $@->rethrow : die $@;
  }
  $self->DESTROY;
  return 1;
}
# set_property( { prop1 => $val1, prop2 => $val2, ... } )
# ret true if success, false if fail
sub set_property {
  my $self = shift;
  my ($props) = @_;
  REST::Neo4p::LocalException->throw("Arg must be a hashref\n") unless ref($props) && ref $props eq 'HASH';
  my $entity_type = ref $self;
  $entity_type =~ s/.*::(.*)/\L$1\E/;
  my $agent = $REST::Neo4p::AGENT;
  my $suffix = $self->_get_url_suffix('property');
  my @ret;
  $suffix =~ s|/[^/]*$||; # strip the '{key}' placeholder
  for (keys %$props) {
    eval {
      $agent->put_data([$entity_type,$$self,$suffix,
			$_], $props->{$_});
    };
    my $e;
    if ($e = Exception::Class->caught('REST::Neo4p::Exception')) {
      # TODO : handle different classes
      $e->rethrow;
    }
    elsif ($@) {
      ref $@ ? $@->rethrow : die $@;
    }
  }
  # create accessors
  if ($REST::Neo4p::CREATE_AUTO_ACCESSORS) {
    for (keys %$props) { $self->_create_accessors($_) unless $self->can($_) }
  }
  return 1;
}

# @prop_values = get_property( qw(prop1 prop2 ...) )
sub get_property {
  my $self = shift;
  my @props = @_;
  my $entity_type = ref $self;
  $entity_type =~ s/.*::(.*)/\L$1\E/;
  my $agent = $REST::Neo4p::AGENT;
  REST::Neo4p::CommException->throw("Not connected\n") unless $agent;
  my $suffix = $self->_get_url_suffix('property');
  my @ret;
  $suffix =~ s|/[^/]*$||; # strip the '{key}' placeholder
  for (@props) {
    my $decoded_resp;
    eval {
      $decoded_resp = $agent->get_data($entity_type,$$self,$suffix,$_);
    };
    my $e;
    if ( $e = Exception::Class->caught('REST::Neo4p::NotFoundError')) {
      push @ret, undef;
    }
    elsif ( $e = Exception::Class->caught()) {
      ref $e ? $e->rethrow : die $e;
    }
    else {
      push @ret, $decoded_resp;
    }
  }
  return @ret == 1 ? $ret[0] : @ret;
}

# $prop_hash = get_properties()
sub get_properties {
  my $self = shift;
  my $entity_type = ref $self;
  $entity_type =~ s/.*::(.*)/\L$1\E/;
  my $agent = $REST::Neo4p::AGENT;
  REST::Neo4p::CommException->throw("Not connected\n") unless $agent;
  my $suffix = $self->_get_url_suffix('property');
  $suffix =~ s|/[^/]*$||; # strip the '{key}' placeholder
  my $decoded_resp;
  eval {
    $decoded_resp = $agent->get_data($entity_type,$$self,$suffix);
  };
  my $e;
  if ($e = Exception::Class->caught('REST::Neo4p::NotFoundException')) {
    return;
  }
  elsif ($e = Exception::Class->caught()) {
    ref $e ? $e->rethrow : die $e;
  }
  return $decoded_resp;
  
}
# remove_property( qw(prop1 prop2 ...) )
sub remove_property {
  my $self = shift;
  my @props = @_;
  my $entity_type = ref $self;
  $entity_type =~ s/.*::(.*)/\L$1\E/;
  my $agent = $REST::Neo4p::AGENT;
  REST::Neo4p::CommException->throw("Not connected\n") unless $agent;
  my $suffix = $self->_get_url_suffix('property');
  foreach (@props) {
    eval {
      $agent->delete_data($entity_type,$$self,$suffix,$_);
    };
    my $e;
    if ($e = Exception::Class->caught('REST::Neo4p::Exception')) {
      # TODO : handle different classes
      $e->rethrow;
    }
    elsif ($@) {
      ref $@ ? $@->rethrow : die $@;
    }
  }
  return 1;
}

sub id { ${$_[0]} }
sub is_batch { shift->_entry->{batch} }
sub entity_type { shift->_entry->{entity_type} }

# $obj = REST::Neo4p::Entity->_entity_by_id($entity_type, $id[, $idx_type]) or
# $node_obj = REST::Neo4p::Node->_entity_by_id($id);
# $relationship_obj = REST::Neo4p::Relationship->_entity_by_id($id)
# $index_obj = REST::Neo4p::Index->_entity_by_id($id, $idx_type);
sub _entity_by_id {
  my $class = shift;
  REST::Neo4p::ClassOnlyException->throw() if (ref $class);
  
  my $entity_type = $class;
  my ($id, $idx_type);
  $entity_type =~ s/.*::(.*)/\L$1\E/;
  if ($entity_type eq 'entity') {
    ($entity_type,$id,$idx_type) = @_;
  }
  else {
    ($id,$idx_type) = @_;
  }
  if ($entity_type eq 'index' && !$idx_type) {
    REST::Neo4p::LocalException->throw("Index requested, but index type not provided in last arg\n");
  }
  unless ($ENTITY_TABLE->{$entity_type}{$id}) {
    # not recorded as object yet
    my $agent = $REST::Neo4p::AGENT;
    REST::Neo4p::CommException->throw("Not connected\n") unless $agent;
    my ($rq, $decoded_resp);
    if ($entity_type eq 'index') {
      # get list of indexes and choose the one (if any) matching the 
      # given index name...
      $rq = "get_${idx_type}_index";
      eval {
	$decoded_resp = $agent->$rq();
      };
      my $e;
      if ($e = Exception::Class->caught('REST::Neo4p::Exception')) {
	# TODO : handle different classes
	$e->rethrow;
      }
      elsif ($@) {
	ref $@ ? $@->rethrow : die $@;
      }
      $decoded_resp = $decoded_resp->{$id};
      unless (defined $decoded_resp) {
	REST::Neo4p::NotFoundException->throw
	  (
	   message => "Index '$id' not found in db\n",
	   neo4j_message => "Neo4j call was successful, but index '$id'".
	                     "was not returned in the list of indexes\n"
	  );

      }
    }
    else {
      # usual way to get entities...
      $rq = "get_${entity_type}";
      eval {
	$decoded_resp = $agent->$rq($id);
      };
      my $e;
      if ($e = Exception::Class->caught('REST::Neo4p::Exception')) {
	# TODO : handle different classes
	$e->rethrow;
      }
      elsif ($@) {
	ref $@ ? $@->rethrow : die $@;
      }
    }
    $class->new_from_json_response($decoded_resp);
  }
  return $ENTITY_TABLE->{$entity_type}{$id}{self};
}

sub _get_url_suffix {
  my $self = shift;
  my ($action) = @_;
  my $entity_type = ref $self;
  $entity_type =~ s/.*::(.*)/\L$1\E/;
  return unless $ENTITY_TABLE->{$entity_type}{_actions};
  my $suffix = $ENTITY_TABLE->{$entity_type}{_actions}{$action};
}

sub _self_url {
  my $self = shift;
  my $entity_type = ref $self;
  $entity_type =~ s/.*::(.*)/\L$1\E/;
  return $ENTITY_TABLE->{$entity_type}{$$self}{self_url};
}

# get the $ENTITY_TABLE entry for the object
sub _entry {
  my $self = shift;
  my $entity_type = ref $self;
  $entity_type =~ s/.*::(.*)/\L$1\E/;
  return $ENTITY_TABLE->{$entity_type}{$$self};
}

sub DESTROY {
  my $self = shift;
  my $entity_type = ref $self;
  $entity_type =~ s/.*::(.*)/\L$1\E/;
  foreach (keys %{$ENTITY_TABLE->{$entity_type}{$$self}}) {
    delete $ENTITY_TABLE->{$entity_type}{$$self}{$_};
  }

  delete $ENTITY_TABLE->{$entity_type}{$$self};

  return;
}

sub _create_accessors {
  my $self = shift;
  my $class = ref $self;
  my ($prop_name) = @_;
  no strict qw(refs);
  *{$class."::$prop_name"} = sub {
    my $caller = shift;
    $caller->get_property( $prop_name );
  };
  *{$class."::set_$prop_name"} = sub { 
    shift->set_property( {$prop_name => $_[0]} );
  };
}

=head1 NAME

REST::Neo4p::Entity - Base class for Neo4j entities

=head1 SYNOPSIS

Not intended to be used directly. Use subclasses
L<REST::Neo4p::Node|REST::Neo4p::Node>,
L<REST::Neo4p::Relationship|REST::Neo4p::Relationship> and
L<REST::Neo4p::Node|REST::Neo4p::Index> instead.

=head1 DESCRIPTION

C<REST::Neo4p::Entity> is the base class for the node, relationship
and index classes which should be used directly. The base class
encapsulates most of the L<REST::Neo4p::Agent|REST::Neo4p::Agent>
calls to the Neo4j server, converts JSON responses to Perl references,
acknowledges errors, and maintains the main object table.

=head1 SEE ALSO

L<REST::Neo4p>, L<REST::Neo4p::Node>, L<REST::Neo4p::Relationship>,
L<REST::Neo4p::Index>.

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

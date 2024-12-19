#$Id$
package REST::Neo4p::Path;
use REST::Neo4p::Exceptions;
use Carp qw(croak carp);
use Scalar::Util qw(blessed);
use strict;
use warnings;
BEGIN {
  $REST::Neo4p::Path::VERSION = '0.4011';
}

sub new {
  my $class = shift;
  bless { _length => 0 }, $class;
}

sub new_from_json_response {
  my $class = shift;
  my ($decoded_resp) = @_;
  return $class->new_from_driver_obj(@_) if blessed $decoded_resp;
  REST::Neo4p::LocalException->throw("Arg does not describe a Neo4j path response\n") unless $decoded_resp->{start} && $decoded_resp->{end} && $decoded_resp->{relationships} && $decoded_resp->{nodes};
  my $obj = bless {}, $class;
  $obj->{_length} = $decoded_resp->{length};
  my @node_urls = @{$decoded_resp->{nodes}};
  my @reln_urls = @{$decoded_resp->{relationships}};

  while (my $node_url = shift @node_urls) {
    my $reln_url = shift @reln_urls;
    my ($node_id) = $node_url =~ /([0-9]+)$/;
    my ($reln_id) = $reln_url =~ /([0-9]+)$/ if $reln_url;
    my ($node, $relationship);
    eval {
      $node = REST::Neo4p::Node->_entity_by_id($node_id);
    };
    if (my $e = REST::Neo4p::Exception->caught()) {
      # TODO : handle different classes
      $e->rethrow;
    }
    elsif ($e = Exception::Class->caught()) {
      (ref $e && $e->can("rethrow")) ? $e->rethrow : die $e;
    }
    push @{$obj->{_nodes}}, $node;
    eval {
      $relationship =  REST::Neo4p::Relationship->_entity_by_id($reln_id) if defined $reln_id;
    };
    if (my $e = REST::Neo4p::Exception->caught()) {
      # TODO : handle different classes
      $e->rethrow;
    }
    elsif ($e = Exception::Class->caught()) {
      (ref $e && $e->can("rethrow")) ? $e->rethrow : die $e;
    }
    push @{$obj->{_relationships}}, $relationship if $relationship;
  }
  REST::Neo4p::LocalException->throw("Extra relationships in path\n") if @reln_urls;
  return $obj;
}

sub new_from_driver_obj {
  my $class = shift;
  my ($pth_obj) = @_;
  my $obj = bless {}, $class;

  my @nodes = $pth_obj->nodes;
  my @relns = $pth_obj->relationships;
  $obj->{_length} = scalar @relns;

  while (my $n = shift @nodes) {
    my $r = shift @relns;
    my ($node, $relationship);
    eval {
      my $id = do { no warnings 'deprecated'; $n->id };
      $node = REST::Neo4p::Node->_entity_by_id($id);
    };
    if (my $e = REST::Neo4p::Exception->caught()) {
      # TODO : handle different classes
      $e->rethrow;
    }
    elsif ($e = Exception::Class->caught()) {
      (ref $e && $e->can("rethrow")) ? $e->rethrow : die $e;
    }
    push @{$obj->{_nodes}}, $node;
    eval {
      no warnings 'deprecated';  # id() in Neo4j 5
      $relationship =  REST::Neo4p::Relationship->_entity_by_id($r->id) if defined $r;
    };
    if (my $e = REST::Neo4p::Exception->caught()) {
      # TODO : handle different classes
      $e->rethrow;
    }
    elsif ($e = Exception::Class->caught()) {
      (ref $e && $e->can("rethrow")) ? $e->rethrow : die $e;
    }
    push @{$obj->{_relationships}}, $relationship if $relationship;
  }
  REST::Neo4p::LocalException->throw("Extra relationships in path\n") if @relns;
  return $obj;
}

sub as_simple {
  my $self = shift;
  my $ret;
  my @n = $self->nodes;
  my @r = $self->relationships;
  while (my $n = shift @n) {
    push @$ret, $n->as_simple;
    my $r = shift @r;
    push @$ret, $r->as_simple if defined $r;
  }
  return $ret;
}

sub simple_from_json_response {
  my $class = shift;
  my ($decoded_resp) = @_;
  return $class->new_from_json_response($decoded_resp)->as_simple;
}

sub nodes { @{shift->{_nodes}} }
sub relationships { @{shift->{_relationships}} }

=head1 NAME

REST::Neo4p::Path - Container for Neo4j path elements

=head1 SYNOPSIS

  use REST::Neo4p::Query;
  $query = REST::Neo4p::Query->new(
    'START n=node(0), m=node(1) MATCH p=(n)-[*..3]->(m) RETURN p'
  );
  $query->execute;
  $path = $query->fetch->[0];
  @nodes = $path->nodes;
  @relns = $path->relationships;
  while ($n = shift @nodes) {
    my $r = shift @relns;
    print $r ? $n->id."-".$r->id."->" : $n->id."\n";
  }

=head1 DESCRIPTION

REST::Neo4p::Path provides a simple container for Neo4j paths as returned
by Cypher queries. Nodes and relationships are stored in path order.

Creating de novo instances of this class is really the job of L<REST::Neo4p::Query>.

=head1 METHODS

=over

=item nodes()

 @nodes = $path->nodes;

Get the nodes in path order.

=item relationships()

 @relationships = $path->relationships;

Get the relationships in path order.

=item as_simple()

 $a = $path->as_simple;
 @simple_nodes = grep { $_->{_node} } @$a;
 @simple_relns = grep { $_->{_relationship} } @$a;

Get the path as an array of simple node and relationship hashes (see
L<REST::Neo4p::Node/as_simple()>,
L<REST::Neo4p::Relationship/as_simple()>).

=back

=head1 SEE ALSO

L<REST::Neo4p>, L<REST::Neo4p::Node>, L<REST::Neo4p::Relationship>,
L<REST::Neo4p::Query>.

=head1 AUTHOR

   Mark A. Jensen
   CPAN ID: MAJENSEN
   majensen -at- cpan -dot- org

=head1 LICENSE

Copyright (c) 2012-2022 Mark A. Jensen. This program is free software; you
can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

1;

#$Id$
package REST::Neo4p::Path;
use REST::Neo4p::Exceptions;
use Carp qw(croak carp);
use strict;
use warnings;
BEGIN {
  $REST::Neo4p::Path::VERSION = '0.1282';
}

sub new {
  my $class = shift;
  bless { _length => 0 }, $class;
}

sub new_from_json_response {
  my $class = shift;
  my ($decoded_resp) = @_;
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
    my $e;
    if ($e = Exception::Class->caught('REST::Neo4p::Exception')) {
      # TODO : handle different classes
      $e->rethrow;
    }
    elsif ($@) {
      ref $@ ? $@->rethrow : die $@;
    }
    push @{$obj->{_nodes}}, $node;
    eval {
      $relationship =  REST::Neo4p::Relationship->_entity_by_id($reln_id) if $reln_id;
    };
    if ($e = Exception::Class->caught('REST::Neo4p::Exception')) {
      # TODO : handle different classes
      $e->rethrow;
    }
    elsif ($@) {
      ref $@ ? $@->rethrow : die $@;
    }
    push @{$obj->{_relationships}}, $relationship;
  }
  REST::Neo4p::LocalException->throw("Extra relationships in path\n") if @reln_urls;
  return $obj;
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

C<REST::Neo4p::Path> provides a container for Neo4j paths as returned
by Cypher queries. Nodes and relationships are stored in path order.

Currently, creating de novo instances of class is really the job of 
L<REST::Neo4p::Query|REST::Neo4p::Query>.

=head1 METHODS

=over

=item nodes()

 @nodes = $path->nodes;

=item relationships()

 @relationships = $path->relationships;

=back

=head1 SEE ALSO

L<REST::Neo4p>, L<REST::Neo4p::Node>, L<REST::Neo4p::Relationship>,
L<REST::Neo4p::Query>.

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

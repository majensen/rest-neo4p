#$Id$
use v5.10;
package REST::Neo4p;
use Carp qw(croak carp);
use lib '../../lib';
use REST::Neo4p::Agent;
use REST::Neo4p::Node;
use REST::Neo4p::Index;
use REST::Neo4p::Query;
use REST::Neo4p::Exceptions;
use strict;
use warnings;

BEGIN {
  $REST::Neo4p::VERSION = '0.2200';
}

our $CREATE_AUTO_ACCESSORS = 0;
our @HANDLES;
our $HANDLE = 0;
#our $AGENT;

$HANDLES[0]->{_q_endpoint} = 'cypher';

sub set_handle {
  my $class = shift;
  my ($i) = @_;
  REST::Neo4p::LocalException->throw("Nonexistent handle '$i'") unless defined $HANDLES[$i];
  $HANDLE=$i;
}

sub create_and_set_handle {
  my $class = shift;
  $HANDLE = @HANDLES;
  $HANDLES[$HANDLE]->{_agent} = REST::Neo4p::Agent->new;
  return $HANDLE;
}

sub disconnect_handle {
  my $class = shift;
  my ($i) = @_;
  REST::Neo4p::LocalException->throw("Nonexistent handle '$i'") unless defined $HANDLES[$i];
  delete $HANDLES[$i];
  return 1;
}

sub _set_transaction {
  my $class = shift;
  my ($tx) = @_;
  die "Bad transaction id" unless $tx =~ /^[0-9]+$/;
  return $HANDLES[$HANDLE]->{_transaction} = $tx;
}

sub _transaction {
  my $class = shift;
  return $HANDLES[$HANDLE]->{_transaction};
}

sub _tx_errors {
  my $class = shift;
  return $HANDLES[$HANDLE]->{_tx_errors};
}

sub _clear_transaction {
  my $class = shift;
  delete $HANDLES[$HANDLE]->{_transaction}
}

sub q_endpoint { 
  my $neo4p = shift;
  return $HANDLES[$HANDLE]->{_q_endpoint};
}

sub handle {
  my $neo4p = shift;
  return $HANDLE;
}

sub agent {
  my $neo4p = shift;
  unless (defined $HANDLES[$HANDLE]->{_agent}) {
    eval {
#      $HANDLES[$HANDLE]->{_agent} = $AGENT = REST::Neo4p::Agent->new();
      $HANDLES[$HANDLE]->{_agent} = REST::Neo4p::Agent->new();
    };
    if (my $e = REST::Neo4p::Exception->caught()) {
      # TODO : handle different classes
      $e->rethrow;
    }
    elsif ($e = Exception::Class->caught()) {
      ref $e ? $e->rethrow : die $e;
    }
  }
  return $HANDLES[$HANDLE]->{_agent};
}

# connect($host_and_port)
sub connect {
  my $neo4p = shift;
  my ($server_address, $user, $pass) = @_;
  REST::Neo4p::LocalException->throw("Server address not set\n")  unless $server_address;
  $neo4p->agent->credentials($server_address,'',$user,$pass) if defined $user;
  my $connected = $neo4p->agent->connect($server_address);
  return $HANDLES[$HANDLE]->{_connected} = $connected;
}

sub connected {
  my $neo4p = shift;
  return $HANDLES[$HANDLE]->{_connected};
}
# $node = REST::Neo4p->get_node_by_id($id)
sub get_node_by_id {
  my $neo4p = shift;
  my ($id) = @_;
  my $node;
  REST::Neo4p::CommException->throw("Not connected\n") unless $neo4p->connected;
  eval {
    $node = REST::Neo4p::Node->_entity_by_id($id);
  };
  if (my $e = REST::Neo4p::NotFoundException->caught()) {
    return;
  }
  elsif ($e = Exception::Class->caught) {
    ref $e ? $e->rethrow : die $e;
  }
  return $node;
}

sub get_nodes_by_label {
  my $neo4p = shift;
  my ($label) = @_;
  REST::Neo4p::CommException->throw("Not connected\n") unless $neo4p->connected;
  my $decoded_resp;
  eval {
# following line should work, but doesn't yet (self-discovery issue)
#    $decoded_resp = $AGENT->get_label($label, 'nodes');
    $decoded_resp = $neo4p->agent->get_data('label',$label,'nodes');
    1;
  };
  if (my $e = REST::Neo4p::NotFoundException->caught()) {
    return;
   }
  elsif ($e = Exception::Class->caught) {
    ref $e ? $e->rethrow : die $e;
  }
  my @ret;
  foreach my $node_json (@$decoded_resp) {
    push @ret, REST::Neo4p::Node->new_from_json_response($node_json);
  }
  return @ret;

}

# $reln = REST::Neo4p->get_relationship_by_id($id);
sub get_relationship_by_id {
  my $neo4p = shift;
  my ($id) = @_;
  my $relationship;
  REST::Neo4p::CommException->throw("Not connected\n") unless $neo4p->connected;
  eval {
    $relationship = REST::Neo4p::Relationship->_entity_by_id($id);
  };
  if (my $e = REST::Neo4p::NotFoundException->caught()) {
    return;
   }
  elsif ($e = Exception::Class->caught) {
    ref $e ? $e->rethrow : die $e;
   }
  return $relationship;
}

sub get_index_by_name {
  my $neo4p = shift;
  my ($name, $type) = @_;
  if (grep /^$name$/, qw(node relationship)) {
    my $a = $name;
    $name = $type;
    $type = $a;
  }
  my $idx;
  REST::Neo4p::CommException->throw("Not connected\n") unless $neo4p->connected;
  eval {
    $idx = REST::Neo4p::Index->_entity_by_id($name,$type);
  };
  if (my $e = REST::Neo4p::NotFoundException->caught()) {
    return;
   }
  elsif ($e = Exception::Class->caught) {
    ref $e ? $e->rethrow : die $e;
   }
  return $idx;
}

# @all_reln_types = REST::Neo4p->get_relationship_types
sub get_relationship_types {
  my $neo4p = shift;
  REST::Neo4p::CommException->throw("Not connected\n") unless $neo4p->connected;
  my $decoded_json;
  eval {
    $decoded_json = $neo4p->agent->get_relationship_types();
  };
  my $e;
  if ($e = Exception::Class->caught('REST::Neo4p::Exception')) {
    # TODO : handle different classes
    $e->rethrow;
  }
  elsif ($@) {
    ref $@ ? $@->rethrow : die $@;
  }
  return ref $decoded_json ? @$decoded_json : $decoded_json;
}

sub get_indexes {
  my $neo4p = shift;
  my ($type) = @_;
  unless ($type) {
    REST::Neo4p::LocalException->throw("Type argument (node or relationship) required\n");
  }
  REST::Neo4p::CommException->throw("Not connected\n") unless $neo4p->connected;
  my $decoded_resp;
  eval {
    $decoded_resp = $neo4p->agent->get_data('index',$type);
  };
  my $e;
  if ($e = Exception::Class->caught('REST::Neo4p::Exception')) {
    # TODO : handle different classes
    $e->rethrow;
  }
  elsif ($@) {
    ref $@ ? $@->rethrow : die $@;
  }
  my @ret;
  # this rest method returns a hash, not an array (as for relationships)
  for (keys %$decoded_resp) {
    push @ret, REST::Neo4p::Index->new_from_json_response($decoded_resp->{$_});
  }
  return @ret;
}

sub get_node_indexes { shift->get_indexes('node',@_) }
sub get_relationship_indexes { shift->get_indexes('relationship',@_) }

sub begin_work {
  my $neo4p = shift;
  unless ($neo4p->_check_version(2,0,0,6)) {
    REST::Neo4p::VersionMismatchException->throw("Transactions are not available in Neo4j server version < 2.0.0-M06");
  }
  if ($neo4p->q_endpoint eq 'transaction') {
    REST::Neo4p::TxException->throw("Transaction already initiated");
  }
  $HANDLES[$HANDLE]->{_q_endpoint} = 'transaction';
  delete  $HANDLES[$HANDLE]->{_tx_errors};
  return 1;
}

sub commit {
  my $neo4p = shift;
  unless ($neo4p->_check_version(2,0,0,6)) {
    REST::Neo4p::VersionMismatchException->throw("Transactions are not available in Neo4j server version < 2.0.0-M06");
  }
  return 1 if ($neo4p->q_endpoint eq 'cypher'); # noop, server autocommited
  unless ($neo4p->q_endpoint eq 'transaction') {
    REST::Neo4p::TxException->throw("Unknown REST endpoint '".$neo4p->q_endpoint."'");
  }
  my $resp;
  eval {
    $resp = $neo4p->agent->post_transaction(
      [$neo4p->_transaction,'commit']
     );
  };
  if (my $e = REST::Neo4p::Exception->caught()) {
    # TODO : handle different classes
    $e->rethrow;
  }
  elsif ($e = Exception::Class->caught()) {
    ref $e ? $e->rethrow : die $e;
  }
  REST::Neo4p->_clear_transaction;
  # got response, see if errors
  $DB::single=1;
  $HANDLES[$HANDLE]->{_tx_errors} = $resp->{errors};
  return !(scalar @{$resp->{errors}});
}

sub rollback {
  my $neo4p = shift;
  unless ($neo4p->_check_version(2,0,0,6)) {
    REST::Neo4p::VersionMismatchException->throw("Transactions are not available in Neo4j server version < 2.0.0-M06");
  }
  if ($neo4p->q_endpoint eq 'cypher') {
    REST::Neo4p::TxException->throw("Rollback attempted in auto-commit mode");
  }
  unless ($neo4p->q_endpoint eq 'transaction') {
    REST::Neo4p::TxException->throw("Unknown REST endpoint '".$neo4p->q_endpoint."'");
  }
  eval {
    $neo4p->agent->delete_transaction(REST::Neo4p->_transaction);
  };
  if (my $e = REST::Neo4p::Exception->caught()) {
    # TODO : handle different classes
    $e->rethrow;
  }
  elsif ($e = Exception::Class->caught()) {
    ref $e ? $e->rethrow : die $e;
  }
  return $neo4p->_clear_transaction;
}

sub neo4j_version {
  my $neo4p = shift;
  my $v = my $a = $neo4p->agent->{_actions}{neo4j_version};
  return unless defined $v;
  my ($major, $minor, $patch, $milestone) =
    $a =~ /^(?:([0-9]+)\.)(?:([0-9]+)\.)?([0-9]+)?(?:-M([0-9]+))?/;
  wantarray ? ($major,$minor,$patch,$milestone) : $v;
}

sub _check_version {
  my $neo4p = shift;
  my ($major, $minor, $patch, $milestone) = @_;
  my ($M,$m,$p,$s) = $neo4p->neo4j_version;
  my ($current, $requested);
  $current = $requested = 0;
  for ($M,$m,$p) {
    $current += $_||0;
    $current *= 100;
  }
  for ($major,$minor,$patch) {
    $requested += $_||0;
    $requested *= 100;
  }
  if (defined $milestone && defined $s) {
    $current += $s;
    $requested += $milestone;
  }
  return $requested <= $current;
}

sub DESTROY {
  my $self = shift;
  delete $HANDLES[$self->handle];
  return;
}

=head1 NAME

REST::Neo4p - Perl object bindings for a Neo4j database

=head1 SYNOPSIS

  use REST::Neo4p;
  REST::Neo4p->connect('http://127.0.0.1:7474');
  $i = REST::Neo4p::Index->new('node', 'my_node_index');
  $i->add_entry(REST::Neo4p::Node->new({ name => 'Fred Rogers' }),
                                       guy  => 'Fred Rogers');
  $index = REST::Neo4p->get_index_by_name('my_node_index','node');
 ($my_node) = $index->find_entries('guy' => 'Fred Rogers');
  $new_neighbor = REST::Neo4p::Node->new({'name' => 'Donkey Hoty'});
  $my_reln = $my_node->relate_to($new_neighbor, 'neighbor');

  $query = REST::Neo4p::Query->new("START n=node(".$my_node->id.")
                                    MATCH p = (n)-[]->()
                                    RETURN p");
  $query->execute;
  $path = $query->fetch->[0];
  @path_nodes = $path->nodes;
  @path_rels = $path->relationships;

Batch processing (see L<REST::Neo4p::Batch> for more)

 #!perl
 # loader...
 use REST::Neo4p;
 use REST::Neo4p::Batch;
 
 open $f, shift() or die $!;
 batch {
   while (<$f>) {
    chomp;
    ($name, $value) = split /\t/;
    REST::Neo4p::Node->new({name => $name, value => $value});
   } 'discard_objs';
 exit(0);

=head1 DESCRIPTION

REST::Neo4p provides a Perl 5 object framework for accessing and
manipulating a L<Neo4j|http://neo4j.org> graph database server via the
Neo4j REST API. Its goals are

(1) to make the API as transparent as possible, allowing the user to
work exclusively with Perl objects, and

(2) to exploit the API's self-discovery mechanisms, avoiding as much
as possible internal hard-coding of URLs.

Neo4j entities are represented by corresponding classes:

=over

=item *

Nodes : L<REST::Neo4p::Node|REST::Neo4p::Node>

=item *

Relationships : L<REST::Neo4p::Relationship|REST::Neo4p::Relationship>

=item *

Indexes : L<REST::Neo4p::Index|REST::Neo4p::Index>

=back

Actions on class instances have a corresponding effect on the database
(i.e., REST::Neo4p approximates an ORM).

The class L<REST::Neo4p::Query> provides a DBIesqe Cypher query facility.

=head2 Property Auto-accessors

Depending on the application, it may be natural to think of properties
as fields of your nodes and relationships. To create accessors named
for the entity properties, set

 $REST::Neo4p::CREATE_AUTO_ACCESSORS = 1;

Then, when L<set_property()|REST::Neo4p::Node/set_property()> is used
to first create and set a property, accessors will be created on the
class:

 $node1->set_property({ flavor => 'strange', spin => -0.5 });
 printf "Quark has flavor %s\n", $node1->flavor;
 $node1->set_spin(0.5);

If your point of reference is the database, rather than the objects,
auto-accessors may be confusing, since once the accessor is created
for the class, it will exist for all future instances:

 print "Yes I can!\n" if REST::Neo4p::Node->new()->can('flavor');

but there is no fundamental reason why new nodes or relationships must
have the property (it is NoSQL, after all). Therefore this is a choice
for you to make; the default is I<no> auto-accessors.

=head2 Application-level constraints

L<REST::Neo4p::Constrain> provides a flexible means for creating,
enforcing, serializing and loading property and relationship
constraints on your database through REST::Neo4p. It allows you, for
example, to specify "kinds" of nodes based on their properties,
constrain properties and the values of properties for those nodes, and
then specify allowable relationships between kinds of nodes.

Constraints can be enforced automatically, causing exceptions to be
thrown when constraints are violated. Alternatively, you can use
validation functions to test properties and relationships, including
those already present in the database.

This is a mixin that is not I<use>d automatically by REST::Neo4p. For
details and examples, see L<REST::Neo4p::Constrain> and
L<REST::Neo4p::Constraint>.

=head1 CLASS METHODS

=over

=item connect()

 REST::Neo4p->connect( $server );
 REST::Neo4p->connect( $server, $user, $pass );

=item agent()

 REST::Neo4p->agent->credentials( $server, '', $user, $pass);
 REST::Neo4p->connect($server);

Returns the underlying L<REST::Neo4p::Agent> (which ISA L<LWP::UserAgent>).

=item neo4j_version()

 $version = REST::Neo4p->neo4j_version;

Returns the server's neo4j version number, or undef if not connected.

=item get_node_by_id()

 $node = REST::Neo4p->get_node_by_id( $id );

Returns false if node C<$id> does not exist in database.

=item get_nodes_by_label() B<Neo4j Server Version 2.0>

 @nodes = REST::Neo4p->get_nodes_by_label( $label );

Returns false if no nodes with given label in database.

=item get_relationship_by_id()

 $relationship = REST::Neo4p->get_relationship_by_id( $id );

Returns false if relationship C<$id> does not exist in database.

=item get_index_by_name()

 $node_index = REST::Neo4p->get_index_by_name( $name, 'node' );
 $relationship_index = REST::Neo4p->get_index_by_name( $name, 'relationship' );

Returns false if index C<$name> does not exist in database.

=item get_relationship_types()

 @all_relationship_types = REST::Neo4p->get_relationship_types;

=item get_indexes(), get_node_indexes(), get_relationship_indexes()

 @all_indexes = REST::Neo4p->get_indexes;
 @node_indexes = REST::Neo4p->get_node_indexes;
 @relationship_indexes = REST::Neo4p->get_relationship_indexes;


=back

=head1 SEE ALSO

L<REST::Neo4p::Node>,L<REST::Neo4p::Relationship>,L<REST::Neo4p::Index>,
L<REST::Neo4p::Query>, L<REST::Neo4p::Path>, L<REST::Neo4p::Batch>,
L<REST::Neo4p::Constrain>, L<REST::Neo4p::Constraint>.

=head1 AUTHOR

    Mark A. Jensen
    CPAN ID: MAJENSEN
    majensen -at- cpan -dot- org

=head1 LICENSE

Copyright (c) 2012-2013 Mark A. Jensen. This program is free software; you
can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

1;


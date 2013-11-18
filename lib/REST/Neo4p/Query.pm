#$Id$
use v5.10;
package REST::Neo4p::Query;
use REST::Neo4p::Path;
use REST::Neo4p::Exceptions;
use JSON::Streaming::Reader;
use Tie::IxHash;
use File::Temp qw(:seekable);
use Carp qw(croak carp);
use strict;
use warnings;
no warnings qw(once);
BEGIN {
  $REST::Neo4p::Query::VERSION = '0.2200';
}

my $BUFSIZE = 4096;

sub new {
  my $class = shift;
  my ($q_string, $params) = @_;
  unless (defined $q_string and !ref $q_string) {
    REST::Neo4p::LocalException->throw( "First argument must be the query string\n");
  }
  unless (!defined $params || ref($params) eq 'HASH') {
    REST::Neo4p::LocalException->throw( "Second argment must be a hashref of query parameters\n" );
  }
  $q_string =~ s/\s/ /g;
  ($q_string) = $q_string =~ m/^\s*(.*)\s*$/;
  bless { '_query' => $q_string,
	  '_params' => $params || {},
	  '_handle' => REST::Neo4p->handle, # current handle
	  'Statement' => $q_string,
	  'NUM_OF_PARAMS' => $params ? scalar keys %$params : 0,
	  'ParamValues' => $params,
	  'ResponseAsObjects' => 1,
	  '_tempfile' => ''
	}, $class;
}
sub tmpf { shift->{_tempfile} }
sub _handle { shift->{_handle} }
sub execute {
  my $self = shift;
  # current handle
  local $REST::Neo4p::HANDLE;
  REST::Neo4p->set_handle($self->_handle);
  REST::Neo4p::CommException->throw("Not connected\n") unless REST::Neo4p->connected;
  my $agent = REST::Neo4p->agent;

  if ($agent->batch_mode) {
    REST::Neo4p::NotSuppException->throw("Query execution not supported in batch mode (yet)\n");
  }
  $self->{_error} = undef;
  $self->{_decoded_resp} = undef;
  $self->{NAME} = undef;
#  my $temp_fh;
#  ($temp_fh, $self->{_tempfile}) = tempfile();
  $self->{_tempfile} = File::Temp->new;
  unless ($self->tmpf) {
    REST::Neo4p::LocalException->throw("Can't create query result tempfile : $!");
  }
  my $resp;
  my $endpt = 'post_'.REST::Neo4p->q_endpoint;
  eval {
    given ($endpt) {
      when (/cypher/) {
	$resp = $agent->$endpt(
	  [], 
	  { query => $self->query, params => $self->params },
	  {':content_file' => $self->tmpf->filename}
	 );
      }
      when (/transaction/) {
	# unfortunately, the order of 'statement' and 'parameters'
	# is strict in the content (2.0.0-M06)
	tie my %stmt, 'Tie::IxHash';
	$stmt{statement} = $self->query;
	$stmt{parameters} = $self->params;
	$resp = $agent->$endpt(
	  [REST::Neo4p->_transaction],
	  { 
	    statements => [ \%stmt ]
	   }
	 );
	REST::Neo4p::CommException->throw("No commit url returned") 
	    unless ($resp->{commit});
      }
      default {
	REST::Neo4p::TxException->throw(
	  "Unknown query REST endpoint '".REST::Neo4p->q_endpoint."'"
	 );
      }
    }
  };
  if (my $e = Exception::Class->caught('REST::Neo4p::Neo4jException') ) {
    $self->{_error} = $e;
    $e->rethrow if ($self->{RaiseError});
    return;
  }
  elsif ($e = Exception::Class->caught()) {
    ref $e ? $e->rethrow : die $e;
  }
  # transaction query response:
  if (REST::Neo4p->q_endpoint eq 'transaction') {
    return $resp; # stub
  }
  # else, cypher query response:
  my ($jsonr,$row_count);
  eval {
    ($jsonr,$row_count) = $self->_prepare_response;
  };
  if (my $e = Exception::Class->caught('REST::Neo4p::LocalException')) {
    $self->{_error} = $e;
    $e->rethrow if ($self->{RaiseError});
    return;
  }
  elsif ($e = Exception::Class->caught()) {
    ref $e ? $e->rethrow : die $e;
  }
  $self->{_iterator} = 
    sub {
      return unless defined $self->tmpf;
      my $row;
      my ($token_type, @data) = @{$jsonr->get_token};
      given ($token_type) {
	when (/start_array/) {
	  $row = $jsonr->slurp;
	}
	when (/end_array/) { # finished
	  $self->finish;
	  return;
	}
	default { # fail
	  REST::Neo4p::LocalException->throw(
	    "Can't parse query response (unexpected token looking for next row)\n"
	   );
	};
      }
      return $self->_process_row($row);
    };
  return $row_count;
}

sub fetchrow_arrayref { 
  my $self = shift;
  unless ( defined $self->{_iterator} ) {
    REST::Neo4p::LocalException->throw("Can't run fetch(), query not execute()'d yet\n");
  }
  $self->{_iterator}->();
}

sub fetch { shift->fetchrow_arrayref(@_) }

sub column_names {
  my $self = shift;
  return $self->{_column_names} && @{$self->{_column_names}};
}

sub err { 
  my $self = shift;
  return $self->{_error} && $self->{_error}->code;
}

sub errstr { 
  my $self = shift;
  return $self->{_error} && ( $self->{_error}->message || $self->{_error}->neo4j_message );
}


sub query { shift->{_query} }
sub params { shift->{_params} }

sub _response_entity {
  my ($resp) = @_;
  if ( ref($resp) eq '' ) { #handle arrays of barewords
    return 'bareword';
  }
  elsif (defined $resp->{self}) {
    for ($resp->{self}) {
      m|data/node| && do {
	return 'Node';
	last;
      };
      m|data/relationship| && do {
	return 'Relationship';
	last;
      };
      do {
	REST::Neo4p::QueryResponseException->throw("Can't identify object type by JSON response\n");
      };
    }
  }
  elsif (defined $resp->{start} && defined $resp->{end}
	   && defined $resp->{nodes}) {
    return 'Path';
  }
  else {
    REST::Neo4p::QueryResponseException->throw("Can't identify object type by JSON response (2)\n");
  }
}

sub _prepare_response {
  my $self = shift;

  # set up iterator
  my $columns_elt;
  my $buf;
  my $jsonr = JSON::Streaming::Reader->for_stream($self->tmpf);

  # get column names
  while ( my $ret = $jsonr->get_token ) {
    if ($$ret[0] eq 'start_property' && $$ret[1] eq 'columns') {
      $columns_elt = $jsonr->slurp;
      last;
    }
  } 
  unless ($columns_elt) {
    REST::Neo4p::LocalException->throw("Can't parse query reponse json (missing 'columns' element)\n");
  }

  # get number of rows
  my $row_count = 0;
  my $in_data;
  while ( my $ret = $jsonr->get_token ) {
    my ($token_type, @data) = @$ret;
    for ($token_type) {
      /start_property/ && do {
        if ($data[0] && $data[0] eq 'data') {
	  $in_data = 1;
	}
	else {
	  REST::Neo4p::LocalException->throw("Can't parse query response (data token not found)\n");
	}
	last;
      };
      /start_array/ && do {
	if ($in_data) {
	  # count rows
	  while ( $ret = $jsonr->get_token ) {
	    ($token_type, @data) = @$ret;
	    if ($token_type eq 'start_array') {
	      $row_count++;
	      $jsonr->skip;
	    }
	    elsif ( $token_type eq 'end_array' ) { # end of the data array
	      # we're done
	      1;
	    }
	    else {
#	      REST::Neo4p::LocalException->throw("Can't parse query response (array representing data row expected and not found)\n");
	      1;
	    }
	  }
	}
	else {
	  REST::Neo4p::LocalException->throw("Can't parse query response (start of data array not found)\n");
	}
	last;
      };
      do {
	die "Why am I here?";
      };
    }
  }

  seek $self->tmpf, 0, 0;
  $jsonr = JSON::Streaming::Reader->for_stream($self->tmpf);
  while ( my $ret = $jsonr->get_token ) {
    if ($$ret[0] eq 'start_property' && $$ret[1] eq 'columns') {
      $jsonr->skip;
      last;
    }
  }
  $self->{NAME} = $columns_elt;
  $self->{NUM_OF_FIELDS} = scalar @$columns_elt;
  # position parser cursor
  undef $in_data;
  my $cursor_set;
  CURSOR :
      while ( my ($token_type, @data) = @{$jsonr->get_token} ) {
	TOKEN_TYPE :
	    for ($token_type) {
	      /start_property/ && do {
		$in_data = 1 if ($data[0] && $data[0] eq 'data');
		last TOKEN_TYPE;
	      };
	      /start_array/ && do {
		if ($in_data) {
		  $cursor_set = 1;
		  last CURSOR;
		}
		last TOKEN_TYPE;
	      };
	    }
      }
  unless ($cursor_set) {
    REST::Neo4p::LocalException->throw("Can't parse query response (start of data array not found)\n");
  }
  return ($jsonr, $row_count);
}

sub _process_row {
  my $self = shift;
  my ($row) = @_;
  my @ret;
  foreach my $elt (@$row) {
    given (ref($elt)) {
      when (!$_)  {
	push @ret, $elt;
      }
      when (/HASH/) {
	my $entity_type;
	eval {
	  $entity_type = _response_entity($elt);
	};
	my $e;
	if ($e = Exception::Class->caught()) {
	  ref $e ? $e->rethrow : die $e;
	}
	my $entity_class = 'REST::Neo4p::'.$entity_type;
	push @ret, $self->{ResponseAsObjects} ?
	  $entity_class->new_from_json_response($elt) :
	    $entity_class->simple_from_json_response($elt);
	last;
      }
      when (/ARRAY/) {
	for my $ary_elt (@$elt) {
	  my $entity_type;
	  eval {
	    $entity_type = _response_entity($ary_elt);
	  };
	  my $e;
	  if ($e = Exception::Class->caught()) {
	    ref $e ? $e->rethrow : die $e;
	  }
	  if ($entity_type eq 'bareword') {
	    push @ret, $ary_elt;
	  }
	  else {
	    my $entity_class = 'REST::Neo4p::'.$entity_type;
	    push @ret, $self->{ResponseAsObjects} ?
	      $entity_class->new_from_json_response($ary_elt) :
		$entity_class->simple_from_json_response($ary_elt) ;
	  }
	}
      }
      default {
	REST::Neo4p::QueryResponseException->throw("Can't parse query response (row doesn't make sense)\n");
      }
    }
  }
  return \@ret;
}
sub finish {
  my $self = shift;
  delete $self->{_tempfile};
  return 1;
}

sub DESTROY {
  my $self = shift;
  delete $self->{_tempfile};
}

=head1 NAME

REST::Neo4p::Query - Execute Neo4j Cypher queries

=head1 SYNOPSIS

 REST::Neo4p->connect('http:/127.0.0.1:7474');
 $query = REST::Neo4p::Query->new('START n=node(0) RETURN n');
 $query->execute;
 $node = $query->fetch->[0];
 $node->relate_to($other_node, 'link');

=head1 DESCRIPTION

REST::Neo4p::Query encapsulates Neo4j Cypher language queries,
executing them via L<REST::Neo4p::Agent> and returning an iterator
over the rows, in the spirit of L<DBI>.

=head2 Streaming

L<C<execute()>|/execute()> captures the Neo4j query response in a temp
file. L<C<fetch()>|/fetch()> iterates over the JSON in the response using
L<JSON::Streaming::Reader|JSON::Streaming::Reader>. So go ahead and
make those 100 meg queries. The tempfile is unlinked after the
iterator runs out of rows, or upon object destruction, which ever
comes first.

=head2 Paths

If your query returns a path, L<C<fetch()>|/fetch()> returns a
L<REST::Neo4p::Path> object from which you can obtain the Nodes and
Relationships.

=head1 METHODS

=over

=item new()

 $stmt = 'START n=node({node_id}) RETURN n';
 $query = REST::Neo4p::Query->new($stmt,{node_id => 1});

Create a new query object. First argument is the Cypher query
(required). Second argument is a hashref of parameters (optional).

=item execute()

 $numrows = $query->execute;

Execute the query on the server. Not supported in batch mode.

=item fetch()

=item fetchrow_arrayref()

 $query = REST::Neo4p::Query->new('START n=node(0) RETURN n, n.name');
 $query->execute;
 while ($row = $query->fetch) { 
   print 'It works!' if ($row->[0]->get_property('name') == $row->[1]);
 }

Fetch the next row of returned data (as an arrayref). Nodes are
returned as L<REST::Neo4p::Node|REST::Neo4p::Node> objects,
relationships are returned as
L<REST::Neo4p::Relationship|REST::Neo4p::Relationship> objects,
scalars are returned as-is.

=item err(), errstr()

  $query->execute;
  if ($query->err) {
    printf "status code: %d\n", $query->err;
    printf "error message: %s\n", $query->errstr;
  }

Returns the HTTP error code and Neo4j server error message if an error
was encountered on execution. 

=item finish()

  while (my $row = $q->fetch) {
    if ($row->[0] eq 'What I needed') {
      $q->finish();
      last;
    }
  }

Call finish() to unlink the tempfile before all items have been
fetched.

=back

=head2 ATTRIBUTES

=over 

=item RaiseError

 $q->{RaiseError} = 1;

Set C<$query-E<gt>{RaiseError}> to die immediately (e.g., to catch the exception in an C<eval> block).

=item ResponseAsObjects

 $q->{ResponseAsObjects} = 0;
 $plain_perl = $q->fetch;

If set to true (the default), query reponses are returned as
REST::Neo4p objects.  If false, nodes, relationships and paths are
returned as simple perl structures.  See
L<REST::Neo4p::Node/as_simple()>,
L<REST::Neo4p::Relationship/as_simple()>,
L<REST::Neo4p::Path/as_simple()> for details.

=back

=head1 SEE ALSO

L<REST::Neo4p>, L<REST::Neo4p::Path>, L<REST::Neo4p::Agent>.

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

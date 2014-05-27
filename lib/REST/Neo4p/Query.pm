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
  $REST::Neo4p::Query::VERSION = '0.2252';
}

#my $BUFSIZE = 4096;

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
#	  'ParamValues' => $params,
	  'ResponseAsObjects' => 1,
	  '_tempfile' => ''
	}, $class;
}
sub tmpf { shift->{_tempfile} }
sub _handle { shift->{_handle} }
sub execute {
  my $self = shift;
  my @params = @_;
  my %params;
  if (@params) {
    %params = ref $params[0] ? %{$params[0]} : @params;
    $self->{_params} = \%params;
  }
  # current handle
  local $REST::Neo4p::HANDLE;
  REST::Neo4p->set_handle($self->_handle);
  REST::Neo4p::CommException->throw("Not connected\n") unless REST::Neo4p->connected;
  my $agent = REST::Neo4p->agent;

  if ($agent->batch_mode) {
    REST::Neo4p::NotSuppException->throw("Query execution not supported in batch mode (yet)\n");
  }
  delete $self->{_error};
  delete $self->{_error_list};
  delete $self->{_decoded_resp};
  delete $self->{NAME};
#  my $resp;
  my $endpt = 'post_'.REST::Neo4p->q_endpoint;
  $self->{_tempfile} = File::Temp->new;
  unless ($self->tmpf) {
    REST::Neo4p::LocalException->throw(
      "Can't create query result tempfile : $!\n"
     );
  }
  eval {
    use experimental qw/smartmatch/;
    given ($endpt) {
      when (/cypher/) {
	$agent->$endpt(
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
	$agent->$endpt(
	  [REST::Neo4p->_transaction],
	  { 
	    statements => [ \%stmt ]
	   },
	  {':content_file' => $self->tmpf->filename}
	 );
	if (-s $self->tmpf->filename) {
	  my $jsonr = JSON::Streaming::Reader->for_stream($self->tmpf);
	  my $errors;
	  while (my $ret = $jsonr->get_token) {
	    if ($$ret[0] eq 'start_property' && $$ret[1] eq 'errors') {
	      $errors = $jsonr->slurp;
	      last;
	    }
	  }
	  $self->tmpf->seek(0,0);
	  $DB::single=1 if !defined $errors;
	  if (my @e = @$errors) {
	    REST::Neo4p::TxQueryException->throw( 
	      error => "Query within transaction returned errors (see error_list)\n",
	      error_list => \@e, code => '304');
	  }
	}
      }
      default {
	REST::Neo4p::TxException->throw(
	  "Unknown query REST endpoint '".REST::Neo4p->q_endpoint."'\n"
	 );
      }
    }
  };
  if (my $e = REST::Neo4p::Neo4jException->caught ) {
    $self->{_error} = $e;
    $e->can('error_list') && ($self->{_error_list} = $e->error_list);
    $e->rethrow if ($self->{RaiseError});
    return;
  }
  elsif ($e = REST::Neo4p::Exception->caught()) {
    $self->{_error} = $e;
    $e->rethrow if ($self->{RaiseError});
    return;
  }
  elsif ( $e = Exception::Class->caught) {
    ref $e ? $e->rethrow : die $e;
  }
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
      use experimental qw/smartmatch/;
      return unless defined $self->tmpf;
      my $row;
      my ($token_type, @data) = @{$jsonr->get_token};
      given ($token_type) {
	when (/start_array/) { # return from cypher endpt
	  $row = $jsonr->slurp;
	}
	when (/start_object/) { # return from transaction endpt
	  my ($tok,$key) = @{$jsonr->get_token};
	  unless ($key eq 'row') {
	    REST::Neo4p::LocalException->throw("Can't parse query response (expecting row property in object)");
	  }
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

sub err_list {
  my $self = shift;
  return $self->{_error} && $self->{_error_list};
}


sub query { shift->{_query} }
sub params { shift->{_params} }

sub _response_entity {
  my ($resp) = @_;
  use experimental qw/smartmatch/;
  if ( ref($resp) eq '' ) { #handle arrays of barewords
    return 'bareword';
  }
  elsif (defined $resp->{self}) {
    given ($resp->{self}) {
      when (m|data/node|) {
	return 'Node';
      }
      when (m|data/relationship|) {
	return 'Relationship';
      }
      default {
	REST::Neo4p::QueryResponseException->throw(message => "Can't identify object type by JSON response\n");
      }
    }
  }
  elsif (defined $resp->{start} && defined $resp->{end}
	   && defined $resp->{nodes}) {
    return 'Path';
  }
  else {
    return 'Simple';
#    REST::Neo4p::QueryResponseException->throw("Can't identify object type by JSON response (2)\n");
  }
}

sub _prepare_response {
  use experimental qw/smartmatch/;
  my $self = shift;
  if (-z $self->tmpf->filename) {
    REST::Neo4p::EmptyQueryResponseException->throw("Server response body is zero length\n");
  }
  # set up iterator
  my $columns_elt;
  my $buf;
  my $jsonr = JSON::Streaming::Reader->for_stream($self->tmpf);
  my $endpt = REST::Neo4p->q_endpoint;
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
    given ($token_type) {
      when ('start_property') {
        if ($data[0] && $data[0] eq 'data') {
	  $in_data = 1;
	}
	else {
	  REST::Neo4p::LocalException->throw("Can't parse query response (data token not found)\n");
	}
      }
      when ('start_array') {
	if ($in_data) {
	  # count rows
	  # cypher endpoint: data is an array of arrays (each a row)
	  # transactional endpoint: data is an array of hashes (each a row)
	  while ( $ret = $jsonr->get_token ) {
	    ($token_type, @data) = @$ret;
	    given ($token_type) {
	      when ('start_array') {
		if ($endpt =~ /cypher/) {
		  $row_count++;
		  $jsonr->skip;
		}
		1;
	      }
	      when ('start_object') {
		my ($tok,$key) = @{$jsonr->get_token};
#		$DB::single=1;
		unless ($key eq 'row') {
		  REST::Neo4p::LocalException->throw("Can't parse query response (expecting row property in object)");
		}
		  $row_count++;
		  $jsonr->skip;
	      }
	      when ('end_array' ) { # end of the data array
		# we're done
		$in_data = 0;
		last;
	      }
	      default {
		#	      REST::Neo4p::LocalException->throw("Can't parse query response (array representing data row expected and not found)\n");
		1;
	      }
	    }
	  }
	}
	else {
	  REST::Neo4p::LocalException->throw("Can't parse query response (start of data array not found)\n");
	}
	last;
      }
      default {
	die "Why am I here?";
      }
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
  use experimental qw/smartmatch/;
  my @ret;
  foreach my $elt (@$row) {
    given ($elt) {
       when (!ref) { #bareword
	push @ret, $elt;
      }
      when (ref =~ /HASH/) {
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
      }
      when (ref =~ /ARRAY/) {
	my $array;
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
	    push @$array, $ary_elt;
	  }
	  else {
	    my $entity_class = 'REST::Neo4p::'.$entity_type;
	    push @$array, $self->{ResponseAsObjects} ?
	      $entity_class->new_from_json_response($ary_elt) :
		$entity_class->simple_from_json_response($ary_elt) ;
	  }
	}
	# guess whether to flatten response:
	# if more than one row element, don't flatten, 
	# return an array reference in the response
	push @ret, @$row > 1 ? $array : @$array;
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
iterator runs out of rows, or upon object destruction, whichever
comes first.

=head2 Parameters

C<REST::Neo4p::Query> understands Cypher L<query
parameters|http://docs.neo4j.org/chunked/stable/cypher-parameters.html>. These
are represented in Cypher as simple tokens surrounded by curly braces.

 MATCH (n) WHERE n.first_name = {name} RETURN n

Here, C<{name}> is the named parameter. A single query object can be executed
multiple times with different parameter values:

 my $q = REST::Neo4p::Query->new(
           'MATCH (n) WHERE n.first_name = {name} RETURN n'
         );
 foreach (@names) {
   $q->execute($_);
   while ($row = $q->fetch) {
    ...process
   }
 }

This is very highly recommended over creating multiple query objects like so:

 foreach (@names) {
   my $q = REST::Neo4p::Query->new(
             "MATCH (n) WHERE n.first_name = '$_' RETURN n"
           );
   $q->execute;
   ...
 }

As with any database engine, a large amount of overhead is saved by
planning a parameterized query once. In addition, the REST side of the
Neo4j server currently (Feb 2014) will balk at handling 1000s of
individual queries in a row. Parameterizing queries gets around this
issue.

=head2 Paths

If your query returns a path, L<C<fetch()>|/fetch()> returns a
L<REST::Neo4p::Path> object from which you can obtain the Nodes and
Relationships.

=head2 Transactions

See L<REST::Neo4p/Transaction Support (Neo4j Server Version 2 only)>.

NOTE: Rows returned from the Neo4j transaction endpoint are not
completely specified database objects (see
L<Neo4j docs|http://docs.neo4j.org/chunked/stable/rest-api-transactional.html>). Fetches
on transactional queries will return an array of simple Perl
structures (hashes and arrays) that correspond to the row as returned
in JSON by the server, rather than as REST::Neo4p objects. This is
regardless of the setting of the
L<ResponseAsObjects|REST::Neo4p::Query/ResponseAsObjects> attribute.

=head1 METHODS

=over

=item new()

 $stmt = 'START n=node({node_id}) RETURN n';
 $query = REST::Neo4p::Query->new($stmt,{node_id => 1});

Create a new query object. First argument is the Cypher query
(required). Second argument is a hashref of parameters (optional).

=item execute()

 $numrows = $query->execute;
 $numrows = $query->execute( param1 => 'value1', param2 => 'value2');
 $numrows = $query->execute( $param_hashref );

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

=item err_list()

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
 $row_as_plain_perl = $q->fetch;

If set to true (the default), query reponses are returned as
REST::Neo4p objects.  If false, nodes, relationships and paths are
returned as simple perl structures.  See
L<REST::Neo4p::Node/as_simple()>,
L<REST::Neo4p::Relationship/as_simple()>,
L<REST::Neo4p::Path/as_simple()> for details.

=item Statement

 $stmt = $q->{Statement};

Get the Cypher statement associated with the query object.

=back

=head1 SEE ALSO

L<DBD::Neo4p>, L<REST::Neo4p>, L<REST::Neo4p::Path>, L<REST::Neo4p::Agent>.

=head1 AUTHOR

   Mark A. Jensen
   CPAN ID: MAJENSEN
   majensen -at- cpan -dot- org

=head1 LICENSE

Copyright (c) 2012-2014 Mark A. Jensen. This program is free software; you
can redistribute it and/or modify it under the same terms as Perl
itself.

=cut
1;

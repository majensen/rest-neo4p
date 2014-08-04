
#$Id$
package REST::Neo4p::Query;
use REST::Neo4p::Path;
use REST::Neo4p::Exceptions;
use JSON::XS;
use REST::Neo4p::ParseStream;
use HOP::Stream qw/drop/;
use File::Temp qw(tempfile);
use Carp qw(croak carp);
use strict;
use warnings;
BEGIN {
  $REST::Neo4p::Query::VERSION = '0.3003';
}

our $BUFSIZE = 50000;

sub new {
  my $class = shift;
  my ($q_string, $params) = @_;
  unless (defined $q_string and !ref $q_string) {
    REST::Neo4p::LocalException->throw( "First argument must be the query string\n");
  }
  unless (!defined $params || ref($params) eq 'HASH') {
    REST::Neo4p::LocalException->throw( "Second argment must be a hashref of query parameters\n" );
  }
  bless { '_query' => $q_string,
	  '_params' => $params || {},
	  'Statement' => $q_string,
	  'NUM_OF_PARAMS' => $params ? scalar keys %$params : 0,
	  'ParamValues' => $params,
	  '_tempfile' => ''
	}, $class;
}

sub execute {
  my $self = shift;
  my $agent = $REST::Neo4p::AGENT;
  REST::Neo4p::CommException->throw("Not connected\n") unless $agent;
  if ($agent->batch_mode) {
    REST::Neo4p::NotSuppException->throw("Query execution not supported in batch mode (yet)\n");
  }
  delete $self->{_error};
  delete $self->{_error_list};
  delete $self->{_decoded_resp};
  delete $self->{NAME};

  my $endpt = 'post_'.REST::Neo4p->q_endpoint;
  $self->{_tempfile} = File::Temp->new;
  unless ($self->tmpf) {
    REST::Neo4p::LocalException->throw(
      "Can't create query result tempfile : $!\n"
     );
  }
  my $resp;
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
      }
      default {
	REST::Neo4p::TxException->throw(
	  "Unknown query REST endpoint '".REST::Neo4p->q_endpoint."'\n"
	 );
      }
    }
  };
  my $e;
  if ($e = Exception::Class->caught('REST::Neo4p::Neo4jException') ) {
    $self->{_error} = $e;
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
  my $jsonr = JSON::XS->new;
  my ($buf,$res,$str,$rowstr,$obj);
  my $row_count;
  use experimental 'smartmatch';
  $self->tmpf->read($buf, $BUFSIZE);
  $jsonr->incr_parse($buf);
  eval { # capture j_parse errors
    $res = j_parse($jsonr);
    die 'j_parse: No text to parse' unless $res;
    die 'j_parse: JSON is not a query or txn response' unless $res->[0] =~ /QUERY|TXN/;
    for ($res->[0]) {
      /QUERY/ && do {
	$obj = drop($str = $res->[1]->());
	die 'j_parse: columns key not present' unless $obj && ($obj->[0] eq 'columns');
	$self->{NAME} = $obj->[1];
	$self->{NUM_OF_FIELDS} = scalar @{$obj->[1]};
	$obj = drop($str);
	die 'j_parse: data key not present' unless $obj->[0] eq 'data';
	$rowstr = $obj->[1]->();
	# query iterator
	$self->{_iterator} =  sub {
	  return unless defined $self->tmpf;
	  my $row;
	  my $item;
	  $item = drop($rowstr);
	  unless ($item) {
	    undef $rowstr;
	    return;
	  }
	  $row = $item->[1];
	  if (ref $row) {
	    return $self->_process_row($row);
	  }
	  else {
	    my $ret;
	    eval {
	      if ($row eq 'PENDING') {
		if ($self->tmpf->read($buf, $BUFSIZE)) {
		  $jsonr->incr_parse($buf);
		  $ret = $self->{_iterator}->();
		}
		else {
		  $item = drop($rowstr);
		  $ret = $self->_process_row($item->[1]);
		}

	      }
	      else {
		die "j_parse: barf(qry)"
	      }
	    };
	    if (my $e = Exception::Class->caught()) {
	      if ($e =~ /j_parse|json/i) {
		$e = REST::Neo4p::StreamException->new(message => $e);
		$self->{_error} = $e;
		$e->throw if $self->{RaiseError};
		return;
	      }
	      else {
		die $e;
	      }
	    }
	    return $ret;
	  }
	};
	# error check
	last;
      };
      /TXN/ && do {
	$obj = drop($str = $res->[1]->());
	die 'j_parse: commit key not present' unless $obj && ($obj->[0] eq 'commit');
	$obj = drop($str);
	die 'j_parse: results key not present' unless $obj && ($obj->[0] eq 'results');
	my $res_str = $obj->[1]->();
	my $row_str;
	my $item = drop($res_str);
	$self->{_iterator} = sub {
	  return unless defined $self->tmpf;
	  my $row;
	  unless ($item) {
	    undef $row_str;
	    undef $res_str;
	    return;
	  }
	  my $ret;
	  eval {
	    if ($item->[0] eq 'columns') {
	      $self->{NAME} = $item->[1];
	      $self->{NUM_OF_FIELDS} = scalar @{$item->[1]};
	      $item = drop($res_str); # move to data
	      die 'j_parse: data key not present' unless $item->[0] eq 'data';
	    }
	    if ($item->[0] eq 'data' && ref($item->[1])) {
	      $row_str = $item->[1]->();
	    }
	    if ($row_str) {
	      $row = drop($row_str);
	      if (ref $row && ref $row->[1]) {
		$ret =  $self->_process_row($row->[1]->{row});
	      }
	      elsif (!defined $row) {
		$item = drop($res_str);
		$ret = $self->{_iterator}->();
	      }
	      else {
		if ($row->[1] eq 'PENDING') {
		  $self->tmpf->read($buf, $BUFSIZE);
		  $jsonr->incr_parse($buf);
		  $ret = $self->{_iterator}->();
		}
		else {

		  die "j_parse: barf(txn)";
		}
	      }
	    }
	    else { # $row_str undef
	      $item = drop($res_str);
	      $item = drop($res_str) if $item->[1] =~ /STREAM/;
	    }
	    return if $ret || ($self->err && $self->errobj->isa('REST::Neo4p::TxQueryException'));
	    if ($item && $item->[0] eq 'transaction') {
	      $item = drop($res_str) # skip
	    }
	    if ($item && $item->[0] eq 'errors') {
	      my $err_str = $item->[1]->();
	      my @error_list;
	      while (my $err_item = drop($err_str)) {
		my $err = $err_item->[1];
		if (ref $err) {
		  push @error_list, $err;
		}
		elsif ($err eq 'PENDING') {
		  $self->tmpf->read($buf,$BUFSIZE);
		  $jsonr->incr_parse($buf);
		}
		else {
		  die 'j_parse: error parsing txn error list';
		}
	      }
	      my $e = REST::Neo4p::TxQueryException->new(
		message => "Query within transaction returned errors (see error_list)\n",
		error_list => \@error_list, code => '304'
	       ) if @error_list;
	      $item = drop($item);
	      $e->throw if $e;
	    }
	  };
	  if (my $e = Exception::Class->caught()) {
	    if (ref $e) {
	      $self->{_error} = $e;
	      $e->rethrow if $self->{RaiseError};
	    }
	    elsif ($e =~ /j_parse|json/i) {
	      $e = REST::Neo4p::StreamException->new(message => $e);
	      $self->{_error} = $e;
	      $e->throw if $self->{RaiseError};
	      return;
	    }
	    else {
	      die $e;
	    }
	  }
	  return $ret;

	};
	last;
      };
      # default
      REST::Neo4p::StreamException->throw( "j_parse: unknown item" );
    }
  };
  if (my $e = Exception::Class->caught('REST::Neo4p::LocalException')) {
    $self->{_error} = $e;
    $e->rethrow if ($self->{RaiseError});
    return;
  }
  elsif ($e = Exception::Class->caught()) {
    if (ref $e) {
      $e->rethrow;
    }
    else {
      if ($e =~ /j_parse|json/i) {
	$e = REST::Neo4p::StreamException->new(message => $e);
	$self->{_error} = $e;
	$e->throw if $self->{RaiseError};
	return;
      }
      else {
	die $e;
      }
    }
  }
  1;
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
  return $self->{_error} && ($self->{_error}->code || 599);
}

sub errstr { 
  my $self = shift;
  return $self->{_error} && ( $self->{_error}->message || $self->{_error}->neo4j_message );
}

sub errobj { shift->{_error} }

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
  }
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
	/end_array/ && do { # finished
	  $temp_fh->close;
	  unlink $self->{_tempfile};
	  undef $self->{_tempfile};
	  undef $temp_fh;
	  return;
	};
	do { # fail
	  REST::Neo4p::LocalException->throw("Can't parse query response (unexpected token looking for next row)\n");
	  last;
	};
      }
      foreach my $elt (@$row) {
	for (ref($elt)) {
	  !$_ && do {
	    push @ret, $elt;
	    last;
	  };
	  /HASH/ && do {
	    my $entity_type;
	    eval {
	      $entity_type = _response_entity($elt);
	    };
	    my $e;
	    if ($e = Exception::Class->caught()) {
	      ref $e ? $e->rethrow : die $e;
	    }
	    my $entity_class = 'REST::Neo4p::'.$entity_type;
	    push @ret, $entity_class->new_from_json_response($elt);
	    last;
	  };
	  /ARRAY/ && do {
	    for my $ary_elt (@$elt) {
	      my ($entity_type,$entity_class);
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
		$entity_class = 'REST::Neo4p::'.$entity_type;
		push @ret, $entity_class->new_from_json_response($ary_elt);
	      }
	    }
	    last;
	  };
	  do {
	    REST::Neo4p::QueryResponseException->throw("Can't parse query response (row doesn't make sense)\n");
	  };
	}
      }
      return \@ret;
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
  delete $self->{_iterator};
  delete $self->{_tempfile};
  return 1;
}

sub DESTROY { shift->finish }

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
file. L<C<fetch()>|/fetch()> iterates (in a non-blocking way if
possible) over the JSON in the response using the incremental parser
of L<JSON::XS|JSON::XS> (see L<REST::Neo4p::ParseStream> if
interested). So go ahead and make those 100 meg queries. The tempfile
is unlinked after the iterator runs out of rows, or upon object
destruction, whichever comes first.

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
   $q->execute(name => $_);
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

=item err(), errstr(), errobj()

  $query->execute;
  if ($query->err) {
    printf "status code: %d\n", $query->err;
    printf "error message: %s\n", $query->errstr;
    printf "Exception class was %s\n", ref $query->errobj;
  }

Returns the HTTP error code, Neo4j server error message, and exception
object if an error was encountered on execution.

=back

=head1 SEE ALSO

L<DBD::Neo4p>, L<REST::Neo4p>, L<REST::Neo4p::Path>, L<REST::Neo4p::Agent>.

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

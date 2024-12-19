use v5.10;
package REST::Neo4p::Query;
use REST::Neo4p::Path;
use REST::Neo4p::Exceptions;
use JSON::MaybeXS ();
use REST::Neo4p::ParseStream;
use HOP::Stream qw/drop/;
use Scalar::Util qw(blessed);
use Tie::IxHash;
use File::Temp qw(:seekable);
use Carp qw(croak carp);
use strict;
use warnings;
no warnings qw(once);

BEGIN {
  $REST::Neo4p::Query::VERSION = '0.4011';
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
    REST::Neo4p::NotSuppException->throw("Query execution not supported in batch mode\n");
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
  eval {
    for ($endpt) {
      /cypher/ && do {
	$agent->$endpt(
	  [], 
	  { query => $self->query, params => $self->params },
	  {':content_file' => $self->tmpf->filename}
	 );
	last;
      };
      /transaction/ && do {
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
	last;
      };
      do {
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
    (ref $e && $e->can("rethrow")) ? $e->rethrow : die $e;
  }
  if ( ref(REST::Neo4p->agent) !~ /Neo4j::Driver/ ) {
    $self->_parse_response;
  }
  else { # Neo4j::Driver
    $self->_wrap_statement_result;
  }
  1;
}

sub fetchrow_arrayref { 
  my $self = shift;
  unless ( defined $self->{_iterator} ) {
    REST::Neo4p::LocalException->throw("Can't run fetch(), query not execute()'d yet\nCheck query object for error with err()/errstr()\n");
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


sub _wrap_statement_result {
  my $self = shift;
  my $result = REST::Neo4p->agent->last_result;
  my $errors = REST::Neo4p->agent->last_errors;
  $self->{NAME} = [$result->keys];
  my $n = $self->{NUM_OF_FIELDS} = scalar @{$self->{NAME}};
  $self->{_iterator} = sub {
    my @row;
    my $rec =  $result->fetch;
    return unless $rec;
    eval {
      my $as_object = $self->{ResponseAsObjects};
      for (my $i=0;$i<$n;$i++) {
	my $elt = $rec->get($i);
	my $cvt = sub {
	  return $_[0] unless blessed $_[0];
	  my $cls = $_[0]->isa('Neo4j::Types::Node')         ? 'REST::Neo4p::Node'
	          : $_[0]->isa('Neo4j::Types::Relationship') ? 'REST::Neo4p::Relationship'
	          : $_[0]->isa('Neo4j::Types::Path')         ? 'REST::Neo4p::Path'
	          : undef or return $_[0];  # spatial/temporal values
	  return $as_object ? $cls->new_from_json_response($_[0]) :
	    $cls->simple_from_json_response($_[0]);
	  };
	for ($elt) {
	  blessed $_ && do {  # Neo4j::Types::*, via Neo4j::Driver
	    $elt = $cvt->($elt);
	  };
	  ref eq 'HASH' && do {
	    for (keys %$elt) {
	      $elt->{$_} = $cvt->($elt->{$_})
	    }
	  };
	  ref eq 'ARRAY' && do {
	    for (@$elt) {
	      $_ = $cvt->($_);
	    }
	  };
	  #else
	  push @row, $elt;
	}
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
    # flatten if single array ref returned
    if (@row==1 and ref($row[0]) eq 'ARRAY') {
      return $row[0];
    }
    else {
      return \@row;
    }
  };
  return;
}

# _parse_response sets up an iterator that pulls a row's worth of objects from
# the servers JSON stream, parses the row into objects, and returns the row.
# this iterator is placed in $self->{_iterator} as a side effect.
# It is hit in fetchrow_arrayref.

sub _parse_response {
  my $self = shift;
  my $jsonr = JSON::MaybeXS->new->utf8;
  my ($buf,$res,$str,$rowstr,$obj);
  my $row_count;
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
		$ret =  $self->_process_row($row->[1]->{row}, $row->[1]->{meta});
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
}
sub _response_entity {
  my ($resp,$meta) = @_;
  if ( ref($resp) eq '' ) { #handle arrays of barewords
    return 'bareword';
  }
  elsif ($meta) {
    my $type = $meta->{type};
    $type =~ s/^(.)/\U$1\E/;
    return $type;
  }
  elsif (defined $resp->{self}) {
    for ($resp->{self}) {
      m|data/node| && do {
	return 'Node';
      };
      m|data/relationship| && do {
	return 'Relationship';
      };
      do {
	REST::Neo4p::QueryResponseException->throw(message => "Can't identify object type by JSON response\n");
      };
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
  my ($row,$meta) = @_;
  my @ret;
  foreach my $elt (@$row) {
    my $info;
    if ($meta) {
      $info = shift @$meta;
    }
    for ($elt) {
       !ref && do { #bareword
	 push @ret, $elt;
	 last;
       };
      (ref =~ /HASH/) && do {
	my $entity_type;
	eval {
	  if ($info && $info->{type}) {
	    $elt->{self} = "$$info{type}/$$info{id}";
	    $entity_type = $info->{type};
	    $entity_type =~ s/^(.)/\U$1\E/;
	  }
	  else {
	    $entity_type = _response_entity($elt);
	  }
	};
	my $e;
	if ($e = Exception::Class->caught()) {
	  (ref $e && $e->can("rethrow")) ? $e->rethrow : die $e;
	}
	my $entity_class = 'REST::Neo4p::'.$entity_type;
	push @ret, $self->{ResponseAsObjects} ?
	  $entity_class->new_from_json_response($elt) :
	  $entity_class->simple_from_json_response($elt);
	last;
      };
      (ref =~ /ARRAY/) && do {
	my $array;
	for my $ary_elt (@$elt) {
	  my $entity_type;
	  eval {
	    if ($info && $info->{type}) {
	      $elt->{self} = "$$info{type}/$$info{id}";
	      $entity_type = $info->{type};
	      $entity_type =~ s/^(.)/\U$1\E/;
	    }
	    else {
	      $entity_type = _response_entity($ary_elt);
	    }
	  };
	  my $e;
	  if ($e = Exception::Class->caught()) {
	    (ref $e && $e->can("rethrow")) ? $e->rethrow : die $e;
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
	push @ret, $array;
	last;
      };
      do {
	REST::Neo4p::QueryResponseException->throw("Can't parse query response (row doesn't make sense)\n");
	last;
      };
    }
  }
  # guess whether to flatten response:
  # if more than one row element, don't flatten, 
  # return an array reference in the response
  return (@ret == 1 and ref($ret[0]) eq 'ARRAY') ? $ret[0] : \@ret;
}

sub finish {
  my $self = shift;
  delete $self->{_iterator};
  unlink $self->tmpf->filename if ($self->tmpf);
  delete $self->{_tempfile};
  return 1;
}

sub DESTROY { shift->finish }

=head1 NAME

REST::Neo4p::Query - Execute Neo4j Cypher queries

=head1 SYNOPSIS

 REST::Neo4p->connect('http:/127.0.0.1:7474');
 $query = REST::Neo4p::Query->new('MATCH (n) WHERE n.name = "Boris" RETURN n');
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
are represented in Cypher, unfortunately, as dollar-prefixed tokens.

 MATCH (n) WHERE n.first_name = $name RETURN n

Here, C<$name> is the named parameter. 

Don't forget to escape the dollar sign if you're also doing string interpolation:

 $prop = "n.name";
 $qry = "MATCH (n) WHERE $prop = \$name RETURN n";
 
A single query object can be executed multiple times with different parameter values:

 my $q = REST::Neo4p::Query->new(
           'MATCH (n) WHERE n.first_name = $name RETURN n'
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
Neo4j server will balk at handling 1000s of individual queries in a row.
Parameterizing queries gets around this issue.

=head2 Paths

If your query returns a path, L<C<fetch()>|/fetch()> returns a
L<REST::Neo4p::Path> object from which you can obtain the Nodes and
Relationships.

=head2 Transactions

See L<REST::Neo4p/Transaction Support (Neo4j Version 2.0+)>.

=head1 METHODS

=over

=item new()

 $stmt = 'MATCH (n) WHERE id(n) = $node_id RETURN n';
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

 $query = REST::Neo4p::Query->new('MATCH (n) RETURN n, n.name LIMIT 10');
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

Copyright (c) 2012-2022 Mark A. Jensen. This program is free software; you
can redistribute it and/or modify it under the same terms as Perl
itself.

=cut
1;

package
  REST::Neo4p::Agent::Neo4j::Driver;

use v5.10;
use lib '../../../../../lib'; #testing
use REST::Neo4p::Exceptions;
use URI::Escape;
use Scalar::Util qw/looks_like_number/;
use strict;
use warnings;

my $SAFE_TOK = qr/[\p{PosixAlnum}_]+/;

my @action_tokens = qw/node labels relationship types index schema constraint cypher transaction/;

my @available_actions =
  qw{
      get_data
      delete_data
      post_data
      put_data
      post_cypher
      post_transaction
      get_propertykeys
      get_node
      delete_node
      post_node
      put_node
      get_relationship
      delete_relationship
      put_relationship
      get_labels
      get_label
      get_index
      delete_index
      post_index
      get_node_index
      delete_node_index
      post_node_index
      get_relationship_index
      delete_relationship_index
      post_relationship_index
      get_schema_constraint
      delete_schema_constraint
      post_schema_constraint
      put_schema_constraint
      get_schema_index
      delete_schema_index
      post_schema_index
      put_schema_index
  };

# args:
# get|delete : my @url_components = @args;
# post|put : my ($url_components, $content, $addl_headers) = @args;

# data

sub available_actions {
  my $self = shift;
  return @available_actions;
}

sub get_data {
  my $self = shift;
  my @args = @_;
  my ($action, $args) = _parse_action(\@args);
  unless ($action) {
    REST::Neo4p::LocalException->throw('get_data requires arg');
  }
  my $dispatch = "get_$action";
  $self->$dispatch(@$args);
}

sub delete_data {
  my $self = shift;
  my @args = @_;
  my ($action, $args) = _parse_action(\@args);
  unless ($action) {
    REST::Neo4p::LocalException->throw('delete_data requires arg');
  }
  my $dispatch = "delete_$action";
  $self->$dispatch(@$args);
}

sub post_data {
  my $self = shift;
  my @args = @_;
  my ($action, $args) = _parse_action($args[0]);
  unless ($action) {
    REST::Neo4p::LocalException->throw('post_data requires arg');
  }
  my $dispatch = "post_$action";
  $self->$dispatch(@args);
}

sub put_data {
  my $self = shift;
  my @args = @_;
  my ($action, $args) = _parse_action($args[0]);
  unless ($action) {
    REST::Neo4p::LocalException->throw('post_data requires arg');
  }
  my $dispatch = "put_$action";
  $self->$dispatch(@args);
}

sub _parse_action {
  my ($args) = @_;
  my @action;
  while (@$args) {
    if (! ref($$args[0]) && grep /^$$args[0]$/,@action_tokens) {
      push @action, shift(@$args);
    }
    else {
      last;
    }
  }
  return (join('_',@action),$args);
}

sub _quote_maybe {
  my @ret = map {
    (/^['"].*['"]$/ || looks_like_number $_) ? $_ : "'$_'"
  } @_;
  wantarray ? @ret : $ret[0];
}

sub _throw_unsafe_tok {
  return 1 if (!defined $_[0] || ref $_[0]);
  REST::Neo4p::LocalException->throw("token $_[0] is unsafe") unless ($_[0] =~ /^$SAFE_TOK$/);
  return;
}
# cypher

sub post_cypher {
  my $self = shift;
  my ($ary, $qry) = @_;
  # $ary not used
  my $result = $self->session->run( $qry->{query}, $qry->{params} // () );
  return $result; # ?
}

# TODO: transaction

sub post_transaction {
  my $self = shift;
}


# propertykeys

sub get_propertykeys {
  my $self = shift;
  return $self->run_in_session('call db.propertyKeys()');
}

# node

sub get_node {
  my $self = shift;
  my ($id,@other) = @_;
  my $result;
  unless (defined $id) {
    REST::Neo4p::LocalException->throw("get_node requires id as arg1\n");    
  }
  if (!@other) {
    $result = $self->run_in_session('match (n) where id(n)=$id return n', {id => 0+$id});
  }
  else {
    for ($other[0]) {
      /^labels$/ && do {
	$result = $self->run_in_session('match (n) where id(n)=$id return labels(n)', { id => 0+$id });
	last;
      };
      /^properties$/ && do {
	if (!defined $other[1]) {
	  $result = $self->run_in_session('match (n) where id(n)=$id return properties(n)', {id => 0+$id});
	}
	else {
	  $result = $self->run_in_session('match (n) where id(n)=$id return n[$prop]', {id => 0+$id, prop => $other[1]});
	}
	last;
      };
      /^relationships$/ && do {
	my $ptn='';
	my $type_cond = '';
	for ($other[1]) {
	  /^all$/ && do {
	    $ptn = '(n)-[r]-()';
	    last;
	  };
	  /^in$/ && do {
	    $ptn = '(n)<-[r]-()';
	    last;
	  };
	  /^out$/ && do {
	    $ptn = '(n)-[r]->()';	    
	    last;
	  };
	  REST::Neo4p::LocalException->throw("get_node relationships action '$other[1]' is unknown\n");
	}
	if ($other[2]) {
	  my @types = split /&/,$other[2];
	  $type_cond = 'and type(r) in ['.join(',',_quote_maybe(@types)).']';
	}
	$result = $self->run_in_session(
	  "match $ptn where id(n)=\$id $type_cond return r",
	  { id => 0+$id }
	 );
	last;
      };
      REST::Neo4p::LocalException->throw("get_node action '$other[2]' is unknown\n");
    }
  }
  if ($result) {
    return $result; ###
  }
}

sub delete_node {
  my $self = shift;
  my ($id,@other) = @_;
  my $result;
  _throw_unsafe_tok($_) for @_;
  unless (defined $id) {
    REST::Neo4p::LocalExeception->throw("delete_node requires id as arg1\n");    
  }
  if (!@other) {
    $result = $self->run_in_session('match (n) where id(n)=$id delete n', {id => 0+$id});
  }
  else {
    for ($other[0]) {
      /^properties$/ && do {
	if ($other[1]) {
	  $result = $self->run_in_session("match (n) where id(n)=\$id remove n.$other[1]",{id => 0+$id});
	}
	else {
	  $result = $self->run_in_session('match (n) where id(n)=$id set n = {}',{id => 0+$id})
	}
	last;
      };
      /^labels$/ && do {
	$result = $self->run_in_session("match (n) where id(n)=\$id remove n:$other[1]",{id => 0+$id});
	last;
      };
      REST::Neo4p::LocalException->throw("delete_node action '$other[0]' is unknown\n");
    }
  }
  if ($result) {
    return $result; ###
  }
}

sub post_node {
  my $self = shift;
  my ($url_components,$content,$addl_headers) = @_;
  my $result;
  if (!$url_components || !@$url_components) {
    if (!$content) {
      $result = $self->run_in_session('create (n) return n');
    }
    else {
      my $set_clause = '';
      if (scalar(keys %$content)) {
	_throw_unsafe_tok($_) for keys %$content;
	_throw_unsafe_tok($_) for values %$content;	
	my @assigns = map { "n.$_ = "._quote_maybe($$content{$_}) } sort keys %$content;
	$set_clause = "set ".join(',', @assigns);
      }
      $result = $self->run_in_session("create (n) $set_clause return n");
    }
  }
  else {
    _throw_unsafe_tok($_) for @$url_components;
    my ($id, $ent, @rest) = @$url_components;
    REST::Neo4p::LocalException->throw("'$id' doesn't look like a node id") unless $id =~ /^[0-9]+$/;
    for ($ent) {
      /^labels$/ && do {
	my @lbls = (ref $content ? @$content : $content);
	$result = $self->run_in_session('match (n) where id(n)=$id set n:'.join(':',@lbls),
					{ id => 0+$id });
	last;
      };
      /^relationships$/ && do {
	my ($to_id) = $content->{to} =~ m|node/([0-9]+)$|;
	unless ($to_id) {
	  REST::Neo4p::LocalException->throw("Can't parse 'to' node id from content\n");
	}
	unless ($content->{type}) {
	  REST::Neo4p::LocalException->throw("Create relationship requires 'type' value in content\n");
	}
	my $set_clause = '';
	if (my $props = $content->{data}) {
	  _throw_unsafe_tok($_) for keys %$props;	  
	  _throw_unsafe_tok($_) for values %$props;
	  my @assigns = map { "r.$_="._quote_maybe($$props{$_}) } sort keys %$props;
	  $set_clause = "set ".join(',', @assigns);
	}
	my $type=$content->{type};
	$result = $self->run_in_session(
	  "match (n), (m) where id(n)=\$fromid and id(m)=\$toid create (n)-[r:$type]->(m) $set_clause return r",
	  {fromid=>0+$id, toid=>0+$to_id}
	 ); 
	last;
      };
      # else
      do {
	REST::Neo4p::NotImplException->throw("post action '$_' not implemented for nodes in agent\n");
	last;
      };
    }
  }
  if ($result) {
    return $result; ###
  }
}

sub put_node {
  my $self = shift;
  my ($url_components,$content,$addl_headers) = @_;
  unless (defined $url_components) {
    REST::Neo4p::LocalExeception->throw("put_node requires [\$id,...] as arg1\n");
  }
  _throw_unsafe_tok($_) for @$url_components;
  my ($id,$ent,@rest) = @$url_components;
  REST::Neo4p::LocalException->throw("'$id' doesn't look like a node id") unless $id =~ /^[0-9]+$/;
  my $result;
  for ($ent) {
    /^properties$/ && do {
      if (defined $rest[0]) {
	REST::Neo4p::LocalException->throw('call with put_node([<id>,\'properties\',<prop>],$content) needs content to be plain scalar (the value of <prop>)') if ref($content);
	$result = $self->run_in_session("match (n) where id(n)=\$id set n.$rest[0]=\$value return n", {id => 0+$id, value => $content});
      }
      else {
	_throw_unsafe_tok($_) for keys %$content;
	_throw_unsafe_tok($_) for values %$content;	
	my @assigns = map { "n.$_="._quote_maybe($$content{$_}) } sort keys %$content;
	my $set_clause = "set ".join(',', @assigns);
	$result = $self->run_in_session("match (n) where id(n)=\$id $set_clause return n", {id => 0+$id});
      }
      last;
    };
    /^labels$/ && do {
      # this action needs to remove all labels from node, and add
      # those that are in the call arguments.
      REST::Neo4p::NotImplException->throw('put_node \'labels\' action not yet implemented'); 
      last;
    };
    # else
    do {
      REST::Neo4p::NotImplException->throw("put action '$_' not implemented for nodes in agent\n");
      last;
    };
  }
}

# relationship

sub get_relationship {
  my $self = shift;
  _throw_unsafe_tok($_) for @_;
  my ($id,@other) = @_;
  my $result;
  unless (defined $id) {
    REST::Neo4p::LocalExeception->throw("get_relationship requires id as arg1\n");
  }
  if (!@other) {
    for ($id) {
      /^[0-9]+$/ && do {
	$result = $self->run_in_session('match ()-[r]->() where id(r)=$id return r', {id => 0+$id});
	last;
      };
      /^types$/ && do {
	$result = $self->run_in_session('call db.relationshipTypes()');
	last;
      };
      REST::Neo4p::LocalException->throw("get_relationship action '$id' is unknown\n");
    }
  }
  else {
    for ($other[0]) {
      /^properties$/ && do {
	if (!defined $other[1]) {
	  $result = $self->run_in_session('match ()-[r]->() where id(r)=$id return properties(r)',{id => 0+$id});
	}
	else {
	  $result = $self->run_in_session('match ()-[r]->() where id(r)=$id return r[$prop]',{id => 0+$id, prop => $other[1]});
	}
	last;
      };
      REST::Neo4p::LocalException->throw("get_relationship action '$other[0]' is unknown\n");      
    }
  }
  if ($result) {
    return $result;
  }
}

sub delete_relationship {
  my $self = shift;
  _throw_unsafe_tok($_) for @_;
  my ($id,@other) = @_;
  my $result;
  unless (defined $id) {
    REST::Neo4p::LocalExeception->throw("delete_relationship requires id as arg1\n");    
  }
  if (!@other) {
    $result = $self->run_in_session('match ()-[r]->() where id(r)=$id delete r', {id => 0+$id});
  }
  else {
    for ($other[0]) {
      /^properties$/ && do {
	if ($other[1]) {
	  $result = $self->run_in_session("match ()-[r]->() where id(r)=\$id remove r.$other[1]",{id => 0+$id});
	}
	else {
	  $result = $self->run_in_session('match ()-[r]->() where id(r)=$id set r = {}',{id => 0+$id})
	}
	last;
      };
      REST::Neo4p::LocalException->throw("delete_relationship action '$other[0]' is unknown\n");
    }
  }
  if ($result) {
    return $result; ###
  }
}

# sub post_relationship {
#  my $self = shift;
# }

sub put_relationship {
  my $self = shift;
  my ($url_components,$content,$addl_headers) = @_;
  unless (defined $url_components) {
    REST::Neo4p::LocalExeception->throw("put_node requires [\$id,...] as arg1\n");
  }
  _throw_unsafe_tok($_) for @$url_components;
  my ($id,$ent,@rest) = @$url_components;
  REST::Neo4p::LocalException->throw("'$id' doesn't look like a relationship id") unless $id =~ /^[0-9]+$/;
  REST::Neo4p::LocalException->throw("action for '$id' not specified in arrayref") unless defined $ent;
  my $result;
  for ($ent) {
    /^properties$/ && do {
      if (defined $rest[0]) {
	REST::Neo4p::LocalException->throw('call with put_relationship([<id>,\'properties\',<prop>],$content) needs content to be plain scalar (the value of <prop>)') if ref($content);
	$result = $self->run_in_session("match ()-[r]->() where id(r)=\$id set r.$rest[0]=\$value return r", {id => 0+$id, value => $content});
      }
      else {
	_throw_unsafe_tok($_) for keys %$content;
	_throw_unsafe_tok($_) for values %$content;
	my @assigns = map { "r.$_="._quote_maybe($$content{$_}) } sort keys %$content;
	my $set_clause = "set ".join(',', @assigns);
	$result = $self->run_in_session("match ()-[r]->() where id(r)=\$id $set_clause return r", {id => 0+$id});
      }
      last;
    };
    # else
    do {
      REST::Neo4p::NotImplException->throw("put action '$_' not implemented for relationships in agent\n");
      last;
    };
  }
}

# labels

sub get_labels {
  my $self = shift;
  my $result = $self->run_in_session('call db.labels()');
  return $result;
}

sub get_label {
  my $self = shift;
  _throw_unsafe_tok($_) for @_;
  my ($lbl, @other) = @_;
  my $result;
  REST::Neo4p::LocalException->throw("get_label requires label as arg1\n") unless defined $lbl;
  my $params = $other[-1];
  if (ref $params eq 'HASH') {
    my @cond;
    for my $p (sort keys %$params) {
      push @cond, "n.$p=\$$p";
    }
    my $where_clause = 'where '.join(' and ',@cond);
    $result = $self->run_in_session("match (n:$lbl) $where_clause return n", $params)
  }
  else {
    $result = $self->run_in_session("match (n:$lbl) return n");
  }
  if ($result) {
    return $result;
  }
}

# sub delete_labels{
#   my $self = shift;
# }

# sub post_labels {
#   my $self = shift;
# }

# sub put_labels {
#   my $self = shift;
# }

# indexes

sub get_index {
  my $self = shift;
  my ($ent, $idx, @other) = @_;
  _throw_unsafe_tok($_) for ($ent, $idx);
  my $result;

  if (!$idx) {
    # TODO: returns all indexes - should filter based on $ent
    $result = $self->run_in_session('call db.index.explicit.list()');
  }
  else {
    # find things
    my $params = $other[-1];
    my $seek = ($ent eq 'node' ? 'seekNodes' : 'seekRelationships');
    if (!ref $params) { # key/value
      my ($key, $value) = @other;
      unless (defined $key && defined $value) {
	REST::Neo4p::LocalException->throw("get_index : can't interpret parameters for either key-value or query search\n");
      }
      $value = uri_unescape($value);
      $result = $self->run_in_session("call db.index.explicit.$seek(\$idx,\$key,\$value)",
				      { idx => $idx, key => $key, value => $value });
    }
    elsif (ref $params eq 'HASH') { # query
      unless (defined $params->{query}) {
	REST::Neo4p::LocalException->throw("get_index : key 'query' required in param hash");
      }
      my $search = ($ent eq 'node' ? 'searchNodes' : 'searchRelationships');
      my $query = uri_unescape($params->{query});
      $result = $self->run_in_session("call db.index.explicit.$search(\$idx,\$query)",
				      { idx => $idx, query => $query });
    }
    else {
      REST::Neo4p::LocalException->throw("get_index : can't interpret parameters for either key-value or query search\n");
    }
  }
  if ($result) {
    return $result;
  }
}

sub delete_index {
  my $self = shift;
  _throw_unsafe_tok($_) for @_;
  my ($ent, $idx, @other) = @_;
  my $result;
  REST::Neo4p::LocalException->throw("delete_index required index name at arg 2\n")
      unless defined $idx;
  if (!@other) {
    $result = $self->run_in_session('call db.index.explicit.drop($idx)',{idx => $idx});
  }
  else {
    my $id = pop @other;
    my ($k, $v) = @other;
    my $remove = ($ent eq 'node' ? 'removeNode' : 'removeRelationship');
    my $args = (defined $k ? '$idx, $id, $key' : '$idx, $id' );
    $result = $self->run_in_session("call db.index.explicit.$remove( $args )", {idx => $idx, id => 0+$id, (defined $k ? (key => $k) : ())});
  }
  if ($result) {
    return $result;
  }
}

sub post_index {
  my $self = shift;
  my ($url_components, $content, $addl_parameters) = @_;
  my $result;
  REST::Neo4p::LocalException->throw('post_index requires arrayref of url components as arg1') unless (defined $url_components and ref($url_components) eq 'ARRAY');
  REST::Neo4p::LocalException->throw('post_index requires content hashref as arg2') unless (defined $content and ref($content) eq 'HASH');
  _throw_unsafe_tok($_) for @$url_components;
  my ($ent, $idx, @other) = @$url_components;
  if (! defined $idx) { # create index
    my $for = ($ent eq 'node') ? 'forNodes' : 'forRelationships';
    REST::Neo4p::LocalException->throw("post_index create index requires 'name' key in \$content hash\n") unless defined $content->{name};
    $result = $self->run_in_session("call db.index.explicit.$for(\$name)",$content);
  }
  else {
    REST::Neo4p::LocalException->throw("post_index add to index requires 'key','value'keys in \$content hash\n") unless ($content->{key} && $content->{value});
    if (defined $content->{uri}) { # add entity
      my ($id) = $content->{uri} =~ /(?:node|relationship)\/([0-9]+)$/;
      REST::Neo4p::LocalException->throw("need a node or relationship uri for 'uri' key value in \$content hash\n") unless $id;
      delete $content->{uri};
      $content->{id} = $id;
      $content->{idx} = $idx;
      for ($ent) {
	/^node$/ && do {
	  $result = $self->run_in_session('match (n) where id(n)=$id with n call db.index.explicit.addNode($idx,n,$key,$value)', $content);
	  last;
	};
	/^relationship/ && do {
	  $result = $self->run_in_session('match ()-[r]->() where id(r)=$id with r call db.index.explicit.addRelationship($idx,r,$key,$value)', $content);
	  last;
	};
	do {
	  REST::Neo4p::LocalException->throw("'$ent' is not an indexable entity\n");
	};
      }
    }
    elsif (defined $content->{properties} or
	     defined $content->{type}) { # merge entity
      my $props = delete $content->{properties};
      my $seek = ($ent eq 'node' ? 'seekNodes' : 'seekRelationships');
      # first, check index with key:value
      $result = $self->run_in_session("call db.index.explicit.$seek('$idx','$$content{key}',$$content{value})");
      if ($result->has_next) { # found it
	if (defined $addl_parameters && ($addl_parameters->{uniqueness} eq 'create_or_fail')) {
	  REST::Neo4p::ConflictException->throw("found entity with create_or_fail specified");
	}
	else {
	  return $result;
	}
      }
      # didn't find it, create it
      for ($ent) {
	/^node$/ && do {
	  my $set_clause = '';
	  if (scalar(keys %$props)) {
	    _throw_unsafe_tok($_) for keys %$props;	    
	    _throw_unsafe_tok($_) for values %$props;
	    my @assigns = map { "n.$_="._quote_maybe($$props{$_}) } sort keys %$props;
	    $set_clause = "set ".join(',', @assigns);
	  }
	  $result = $self->run_in_session("create (n) $set_clause with n call db.index.explicit.addNode('$idx',n,\$key,\$value)", $content);
	  last;
	};
	/^relationship/ && do {
	  my ($start) = $content->{start} =~ /node\/([0-9]+)$/;
	  my ($end) = $content->{end} =~ /node\/([0-9]+)$/;
	  REST::Neo4p::LocalException->throw("post_index create relationship requires 'start' and 'end' keys\n")
	      unless (defined $start and defined $end);
	  $content->{start} = $start;
	  $content->{end} = $end;
	  my $type = $content->{type};
	  $result = $self->run_in_session("match (s), (t) where id(s)=\$start and id(t)=\$end create (s)-[r:$type]->(t) with r call db.index.explicit.addRelationship('$idx',r,\$key,\$value)", $content);
	  last;
	};
	do {
	  REST::Neo4p::LocalException->throw("'$ent' is not an indexable entity\n");
	};
      }
    }
    else {
      REST::Neo4p::LocalException->throw("\$content must have either 'uri' or 'properties' keys\n");
    }
  }
  if ($result) {
    return $result;
  }
}

sub get_node_index { shift->get_index("node",@_) }
sub delete_node_index { shift->delete_index("node",@_) }
sub post_node_index { unshift @{$_[1]},'node'; shift->post_index(@_) }
#sub put_node_index { shift->put_index("node",@_) }

sub get_relationship_index { shift->get_index("relationship",@_) }
sub delete_relationship_index { shift->delete_index("relationship",@_) }
sub post_relationship_index { unshift @{$_[1]},'relationship'; shift->post_index(@_) }
#sub put_relationship_index { shift->put_index("relationship",@_) }

# constraint

sub get_schema_constraint {
  my $self = shift;
  _throw_unsafe_tok($_) for @_;
  my ($lbl, $type, $prop) = @_;
  my @constraints;
  my $result;
  $result = $self->run_in_session('call db.constraints()');
  if ($result) {
    while (my $rec = $result->fetch) {
      my ($node_label,$reln_type,$x_prop, $u_prop) =
      $rec->get(0) =~
      /CONSTRAINT ON (?:\( *(?:$SAFE_TOK):($SAFE_TOK) *\)|\(\)-\[(?:$SAFE_TOK):($SAFE_TOK)\]-\(\)) ASSERT (?:exists\((?:$SAFE_TOK)\.($SAFE_TOK)|(?:$SAFE_TOK)\.($SAFE_TOK) IS UNIQUE)/;
      if (defined $node_label) {
	if (defined $x_prop) {
	  push @constraints, {
	    property_keys => [ $x_prop ],
	    label => $node_label,
	    type => "NODE_PROPERTY_EXISTENCE"
	   };
	}
	elsif (defined $u_prop) {
	  push @constraints, {
	    property_keys => [ $u_prop ],
	    label => $node_label,
	    type => "UNIQUENESS"
	   };
	}
	else {
	  warn "unrecognized constraint: '".$rec->get(0)."'";
	}
      }
      elsif (defined $reln_type) {
	if (defined $x_prop) {
	  push @constraints, {
	    property_keys => [ $x_prop ],
	    relationshipType => $reln_type,
	    type => "RELATIONSHIP_PROPERTY_EXISTENCE"
	   };
	}
	else {
	  warn "unrecognized constraint: '".$rec->get(0)."'";
	}
      }
      else {
	warn "unrecognized constraint: '".$rec->get(0)."'";
      }
    }
    no warnings 'uninitialized';
    return [ grep { (!$lbl || ($_->{label} eq $lbl)) &&
		      (!$prop || ($_->{property_keys}[0] eq $prop)) &&
		      (!$type || ( $_->{type} =~ /$type/i )) } @constraints ];
  }
}

sub delete_schema_constraint {
  my $self = shift;
  _throw_unsafe_tok($_) for @_;
  my ($lbl, $type, $prop) = @_;
  unless (defined $prop) {
    REST::Neo4p::LocalException->throw("delete_schema_constraint requires label, constraint type, and property as args\n");
  }
  if ($type eq 'uniqueness') {
    $type = "n.$prop is unique";
  }
  elsif ($type eq 'existence') {
    $type = "exists(n.$prop)";
  }
  else {
    REST::Neo4p::LocalException->throw("type arg must be 'uniqueness' or 'existence', not '$type'\n");
  }
  my $result = $self->run_in_session("drop constraint on (n:$lbl) assert $type");
  if ($result) {
    return $result;
  }
}

sub post_schema_constraint {
  my $self = shift;
  my ($url_components, $content) = @_;
  my ($lbl, $type) = @$url_components;
  unless (defined $type) {
    REST::Neo4p::LocalException->throw("post_schema_constraint requires label and constraint type as elts of arg1\n");
  }
  unless (defined $content && $content->{property_keys}) {
    REST::Neo4p::LocalException->throw("post_schema_constraint requires key 'property_keys' in \$content arg\n");
  }
  _throw_unsafe_tok($_) for @_;
  my $prop = $content->{property_keys}[0];
  _throw_unsafe_tok($prop);
  if ($type eq 'uniqueness') {
    $type = "n.$prop is unique";
  }
  elsif ($type eq 'existence') {
    $type = "exists(n.$prop)";
  }
  else {
    REST::Neo4p::LocalException->throw("type arg must be 'uniqueness' or 'existence', not '$type'\n");
  }
  my $result = $self->run_in_session("create constraint on (n:$lbl) assert $type");
  if ($result) {
    return $result;
  }
}

# sub put_schema_constraint { }

# schema index

sub get_schema_index {
  my $self = shift;
  my ($lbl) = @_;
  unless (defined $lbl) {
    REST::Neo4p::LocalException->throw("get_schema_index requires label as arg1\n");
  }
  my $result = $self->run_in_session('call db.indexes() yield tokenNames as labels, properties where $lbl in labels return { label:$lbl, property_keys:properties }', {lbl => $lbl});
  if ($result) {
    return $result;
  }
}

sub delete_schema_index {
  my $self = shift;
  my ($lbl, $prop) = @_;
  unless ( defined $lbl && defined $prop) {
    REST::Neo4p::LocalException->throw("delete_schema_index requires label at arg1 and property at arg2\n");
  }
  my $result = $self->run_in_session("drop index on :${lbl}(${prop})");
  if ($result) {
    return $result;
  }
}

sub post_schema_index {
  my $self = shift;
  my ($url_components, $content) = @_;
  my ($lbl) = @$url_components;
  unless (defined $lbl) {
    REST::Neo4p::LocalException->throw("post_schema_index requires label as first elt of arg1\n");
  }
  unless (defined $content && $content->{property_keys}) {
    REST::Neo4p::LocalException->throw("post_schema_index requires key 'property_keys' in \$content arg\n");
  }
  my $result;
  for my $prop ( @{$$content{property_keys}} ) {
    $result = $self->run_in_session("create index on :${lbl}(${prop})");
  }
  if ($result) {
    return $result;
  }
}

# sub put_schema_index { }

####
1;
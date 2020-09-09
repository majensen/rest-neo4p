package
  REST::Neo4p::Agent::Neo4j::Driver;

use v5.10;
use lib '../../../../../lib'; #testing
use REST::Neo4p::Exceptions;
use strict;
use warnings;

my @action_tokens = qw/node labels relationship types index schema constraint cypher transaction/;

# args:
# get|delete : my @url_components = @args;
# post|put : my ($url_components, $content, $addl_headers) = @args;

# data

sub get_data {
  my $self = shift;
  my @args = @_;
  my ($action, $args) = _parse_action(\@args);
  my $dispatch = "get_$action";
  $self->$dispatch(@$args);
}

sub delete_data {
  my $self = shift;
  my @args = @_;
  my ($action, $args) = _parse_action(\@args);
  my $dispatch = "delete_$action";
  $self->$dispatch(@$args);
}

sub post_data {
  my $self = shift;
  my @args = @_;
  my ($action, $args) = _parse_action($args[0]);
  my $dispatch = "post_$action";
  $self->$dispatch(@args);
}

sub put_data {
  my $self = shift;
  my @args = @_;
  my ($action, $args) = _parse_action($args[0]);
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

# cypher

sub post_cypher {
  my $self = shift;
  my ($ary, $qry) = @_;
  # $ary not used
  my $result = $self->session->run( $qry->{query}, $qry->{params} // () );
  return [$result->list]; # ?
}

# transaction

sub post_transaction {
  my $self = shift;
}


# propertykeys

sub get_propertykeys {
  my $self = shift;
  return $self->run_in_session('call db.propertyKeys');
}

# node

sub get_node {
  my $self = shift;
  my ($id,@other) = @_;
  my $result;
  unless (defined $id) {
    REST::Neo4p::LocalExeception->throw("get_node requires id as arg1\n");    
  }
  if (!@other) {
    $result = $self->run_in_session('match (n) where id(n)=$id return n', {id => $id});
  }
  else {
    for ($other[0]) {
      /^label$/ && do {
	last;
      };
      /^properties$/ && do {
	if (!defined $other[1]) {
	  $result = $self->run_in_session('match (n) where id(n) = $id return properties(n)', {id => $id});
	}
	else {
	  $result = $self->run_in_session('match (n) where id(n) = $id return n[$prop]', {id => $id, prop => $other[1]});
	}
	last;
      };
      /^relationships$/ && do {
	my $ptn;
	my $type_cond = '';
	for ($other[0]) {
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
	}
	if ($other[1]) {
	  my @types = split /&/,$other[1];
	  $type_cond = 'and type(r) in ['.join(',',@types).']';
	}
	$result = $self->run_in_session(
	  "match $ptn where id(n) = \$id $type_cond return r",
	  { id => $id }
	 );
	last;
      };
    }
  }
  if ($result) {
    return $result; ###
  }
}

sub delete_node {
  my $self = shift;
  my ($id) = @_;
  my $result;
  unless (defined $id) {
    REST::Neo4p::LocalExeception->throw("delete_node requires id as arg1\n");    
  }
  $result = $self->run_in_session('match (n) where id(n)=$id delete n', {id => $id});
  if ($result) {
    return $result; ###
  }
}

sub post_node {
  my $self = shift;
  my ($url_components,$content,$addl_headers) = @_;
  my $result;
  if (!$url_components) {
    if (!$content) {
      $result = $self->run_in_session('create (n) return n');
    }
    else {
      my $set_clause = '';
      for (keys %$content) {
	$set_clause = join(', ',$set_clause, "n.$_ = $$content{$_}")
      }
      $set_clause = "set ".$set_clause;
      $result = $self->run_in_session("create (n) $set_clause return n");
    }
  }
  else {
    my ($id, $ent, @rest) = @$url_components;
    REST::Neo4p::LocalException->throw("'$id' doesn't look like a node id") unless $id =~ /^[0-9]+$/;
    for ($ent) {
      /^labels$/ && do {
	my @lbls = (ref $content ? @$content : $content);
	for my $lbl (@lbls) {
	  $self->run_in_session('match (n) where id(n) = $id set n:$lbl',
				{ id => $id, lbl => $lbl });
	}
	last;
      };
      /^relationships$/ && do {
	my ($to_id) =~ $content->{to} =~ m|node/([0-9]+)$|;
	unless ($to_id) {
	  REST::Neo4p::LocalException->throw("Can't parse 'to' node id from content\n");
	}
	unless ($content->{type}) {
	  REST::Neo4p::LocalException->throw("Create relationship requires 'type' value in content\n");
	}
	my $set_clause = '';
	if (my $props = $content->{data}) {
	  for (keys %$props) {
	    $set_clause = join(', ',$set_clause, "r.$_ = $$props{$_}")
	  }
	  $set_clause = "set $set_clause";
	}
	$result = $self->run_in_session(
	  "match (n), (m) where id(n) = \$fromid and id(m)=\$toid create (n)-[r:\$type]->(m) $set_clause return r",
	  {fromid=>$id, toid=>$to_id,type=>$content->{type}}
	 ); 
	last;
      };
      /^properties$/ && do {
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
}

# relationship

sub get_relationship {
  my $self = shift;
}

sub delete_relationship {
  my $self = shift;
}

sub post_relationship {
  my $self = shift;
}

sub put_relationship {
  my $self = shift;
}

# labels

sub get_labels {
  my $self = shift;
}

sub delete_labels{
  my $self = shift;
}

sub post_labels {
  my $self = shift;
}

sub put_labels {
  my $self = shift;
}


# indexes

sub get_index {
  my $self = shift;
  my ($ent, @args) = @_;
}

sub delete_index {
  my $self = shift;
  my ($ent, @args) = @_;
}

sub post_index {
  my $self = shift;
  my ($ent, @args) = @_;
}

sub put_index {
  my $self = shift;
  my ($ent, @args) = @_;
}

sub get_node_index { shift->get_index("node",@_) }
sub delete_node_index { shift->delete_index("node",@_) }
sub post_node_index { shift->post_index("node",@_) }
sub put_node_index { shift->put_index("node",@_) }

sub get_relationship_index { shift->get_index("relationship",@_) }
sub delete_relationship_index { shift->delete_index("relationship",@_) }
sub post_relationship_index { shift->post_index("relationship",@_) }
sub put_relationship_index { shift->put_index("relationship",@_) }

# constraint

sub get_schema_constraint {
  my $self = shift;
}

sub delete_schema_constraint {
  my $self = shift;
}

sub post_schema_constraint {
  my $self = shift;
}

sub put_schema_constraint {
  my $self = shift;
}

# schema index

# constraint

sub get_schema_index {
  my $self = shift;
}

sub delete_schema_index {
  my $self = shift;
}

sub post_schema_index {
  my $self = shift;
}

sub put_schema_index {
  my $self = shift;
}


####
1;

package REST::Neo4p::Agent::Neo4j::Driver;
use v5.10;
use lib '../../../../../lib'; # testing
use base qw/REST::Neo4p::Agent/;
use Neo4j::Driver;
use JSON::ize;
use REST::Neo4p::Agent::Neo4j::DriverActions;
use REST::Neo4p::Exceptions;
use Try::Tiny;
use URI;
# use MIME::Base64;
use Carp qw/carp/;
use HTTP::Response;
use strict;
use warnings;

BEGIN {
  $REST::Neo4p::Agent::Neo4j::Driver::VERSION = '0.4000';
}

sub new {
  my ($class, @args) = @_;
  my $self = {};
  return bless $self, $class;
}

sub credentials  {
  my $self = shift;
  my ($srv, $realm, $user, $pwd) = @_;
  $self->{_user} = $user;
  $self->{_pwd} = $pwd;
  $self->{_userinfo} = "$user:$pwd";
  $self->{_realm} = $realm;
  return;
}

sub user { shift->{_user} }
sub pwd { shift->{_pwd} }
sub last_result { shift->{_last_result} }
sub last_errors { shift->{_last_errors} }

sub driver { shift->{__driver} }

# these are no-ops
sub default_header { return }
sub add_header { return }
sub remove_header { return }

sub agent {
  my $self = shift;
  return $_[0] ? $self->{_agent} = $_[0] : $self->{_agent};
}

# TODO: pass stream info along to Neo4j::DRiver object

sub stream {
  my $self = shift;
  # do sth
}

sub no_stream {
  my $self = shift;
  # do sth
}

# http, https, bolt (if Neo4j::Bolt)...
sub protocols_allowed {
  my $self = shift;
  my ($protocols) = @_;
  push @{$self->{_protocols_allowed}}, @$protocols;
  return;
}

sub timeout {
  my $self=shift;
  $self->driver && $self->driver->config(timeout => shift());
  return;
}

sub tls {
  my $self=shift;
  $self->driver && $self->driver->config( tls => shift());
}

sub tls_ca {
  my $self = shift;
  $self->driver && $self->driver->config( tls_ca => shift());
}

sub database {
  my $self = shift;
  my ($db) = @_;
  if (defined $db) {
    return $self->{_database} = $db;
  }
  else {
    # Neo4j::Driver defaults to Neo v3 endpoints, but switches to v4 endpoints if 'database' is set.
    # so... don't set the attribute if unset (=> v3)
    return $self->{_database};
  }
}

# subclass override 
sub batch_mode {
  return 0; # batch mode not available
}

# subclass override 
sub batch_length {
  REST::Neo4p::LocalException->throw("Batch mode not available with Neo4j::Driver as agent\n");
}
sub execute_batch {
  REST::Neo4p::LocalException->throw("Batch mode not available with Neo4j::Driver as agent\n");
}

# subclass override
# $agent->connect($url [, $dbname])

sub connect {
  my $self = shift;
  my ($server, $dbname) = @_;
  my ($drv, $uri);
  if (defined $server) {
    $uri = URI->new($server);
    if ($uri->userinfo) {
      my ($u,$p) = split(/:/,$uri->userinfo);
      $self->credentials($uri->host,'',$u,$p);
    }
    $self->server_url($uri->scheme."://".$uri->host.':'.$uri->port);
  }
  if (defined $dbname) {
    $self->database($dbname);
  }
  unless ($self->server_url) {
    REST::Neo4p::Exception->throw("Server not set\n");
  }
  try {
    $drv = Neo4j::Driver->new($self->server_url);
  } catch {
    REST::Neo4p::LocalException->throw("Problem creating new Neo4j::Driver: $_");
  };
  if ($self->user || $self->pwd) {
    $drv->basic_auth($self->user, $self->pwd);
  }
  $self->{__driver} = $drv;
  try {
    if ($uri->scheme =~ /^http/) {
      my $client = $drv->session->{transport}{client};
      $client->GET('/');
      die $client->responseContent unless $client->responseCode =~ /^2/;
      unless ($self->{_actions}{neo4j_version} =
		J($client->responseContent)->{neo4j_version}) {
	$client->GET('/db/data');
	$self->{_actions}{neo4j_version} = J($client->responseContent)->{neo4j_version} or
	  die "Can't find neo4j_version from server";
      }
    }
  } catch {
    REST::Neo4p::CommException->throw($_);
  };
  return 1;
}

sub session {
  my $self = shift;
  unless ($self->driver) {
    REST::Neo4p::LocalException->throw("No driver connection; can't create session ( try \$agent->connect() )\n");
  }
  return $self->driver->session( $self->database ? (database => $self->database) : () );
}

# run_in_session( $query_string, { parm => value, ... } )

sub run_in_session {
  my $self = shift;
  my ($qry, $params) = @_;
  $self->{_last_result} = $self->{_last_errors} = undef;
  $params = {} unless defined $params;
  try {
    $self->{_last_result} = $self->session->run($qry, $params);
  } catch {
    $self->{_last_errors} = $_;
  };
  if ($self->{_last_errors}) {
    try {
      if ($self->last_errors =~ /neo4j enterprise/i) {
	REST::Neo4p::Neo4jTightwadException->throw( error => "You must spend thousands of dollars a year to use this feature; see agent->last_errors()");
      }
      elsif ($self->last_errors =~ /ConstraintValidationFailed/) {
	REST::Neo4p::ConflictException->throw();
      }
      else {
	REST::Neo4p::Neo4jException->throw( error => "Neo4j errors; see agent->last_errors()" );
      }
    } catch {
      if (ref =~ /Conflict/) {
	$_->rethrow;
      }
      else {
	warn $_->error;
      }
      return;
    };
  }
  else {
    return $self->{_last_result} // 1;
  }
}

sub neo4j_version {
  my $self = shift;
  my $v = my $a = $self->{_actions}{neo4j_version};
  return unless defined $v;
  my ($major, $minor, $patch, $milestone) =
    $a =~ /^(?:([0-9]+)\.)(?:([0-9]+)\.)?([0-9]+)?(?:-M([0-9]+))?/;
  wantarray ? ($major,$minor,$patch,$milestone) : $v;
}

# $rq : [get|post|put|delete]
# $action : {neo4j REST endpt action}
# @args : depends on REST rq
# get|delete : my @url_components = @args;
# post|put : my ($url_components, $content, $addl_headers) = @args;

# emulate rest calls with appropriate queries

1;

__END__

sub __do_request {
  my $self = shift;
  my ($rq, $action, @args) = @_;
  use experimental qw/smartmatch/;
  $self->{_errmsg} = $self->{_location} = $self->{_raw_response} = $self->{_decoded_content} = undef;
  my $resp;
  given ($rq) {
    when (/get|delete/) {
      my @url_components = @args;
      my %rest_params = ();
      # look for a hashref as final arg containing field => value pairs
      if (@url_components && ref $url_components[-1] && (ref $url_components[-1] eq 'HASH')) {
	%rest_params = %{ pop @url_components };
      }
      my $url = join('/',$self->{_actions}{$action},@url_components);
      my @params;
      while (my ($p,$v) = each %rest_params) {
	push @params, join('=',$p,$v);
      }
      $url.='?'.join('&',@params) if @params;
      if ($self->batch_mode) {
	1;
      }
# request made here:
      $resp = $self->{_raw_response} = $self->$rq($url);
    }
    when (/post|put/) {
      my ($url_components, $content, $addl_headers) = @args;
      unless (!$addl_headers || (ref $addl_headers eq 'HASH')) {
	REST::Neo4p::LocalException->throw("Arg 3 must be a hashref of additional headers\n");
      }
      no warnings qw(uninitialized);
      my $url = join('/',$self->{_actions}{$action},@$url_components);
      use warnings qw(uninitialized);
      if ($self->batch_mode) {
	$url = ($url_components->[0] =~ /{[0-9]+}/) ? join('/',@$url_components) : $url; # index batch object kludge
	@_ = ($self, 
	      $url,
	      $rq, $content, $addl_headers);
	goto &_add_to_batch_queue;
      }
      $content = $JSON->encode($content) if $content && !$self->isa('Mojo::UserAgent');
# request made here
      $resp  = $self->{_raw_response} = $self->$rq($url, 'Content-Type' => 'application/json', Content=> $content, %$addl_headers);
      1;
    }
  }
  # exception handling
  # rt80471...
  if (length $resp->content) {
    if ($resp->header('Content_Type') =~ /json/) {
      $self->{_decoded_content} = $JSON->decode($resp->content);
    }
  }
  unless ($resp->is_success) {
    if ( $self->{_decoded_content} ) {
      my %error_fields = (
	code => $resp->code,
	neo4j_message => $self->{_decoded_content}->{message},
	neo4j_exception => $self->{_decoded_content}->{exception},
	neo4j_stacktrace =>  $self->{_decoded_content}->{stacktrace}
       );
      my $xclass;
      given ($resp->code) {
	when (404) {
	  $xclass = 'REST::Neo4p::NotFoundException';
	}
	when (409) {
	  $xclass = 'REST::Neo4p::ConflictException';
	}
	default {
	  $xclass = 'REST::Neo4p::Neo4jException';
	}
      }
      if ( $error_fields{neo4j_exception} && 
	     ($error_fields{neo4j_exception} =~ /^Syntax/ )) {
	$xclass = 'REST::Neo4p::QuerySyntaxException';
      }
      $xclass->throw(%error_fields);
    }
    else { # couldn't parse the content as JSON...
      my $xclass = ($resp->code && ($resp->code == 404)) ? 
	'REST::Neo4p::NotFoundException' : 'REST::Neo4p::CommException';
      $xclass->throw( 
	code => $resp->code,
	message => $resp->message
       );
    }
  }
  $self->{_location} = $resp->header('Location');
}

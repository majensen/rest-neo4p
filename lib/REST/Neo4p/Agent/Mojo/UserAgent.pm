#$Id$
use v5.10;
package REST::Neo4p::Agent::Mojo::UserAgent;
use base Mojo::UserAgent;
use REST::Neo4p::Exceptions;
use Carp qw/carp/;
use HTTP::Response;
use strict;
use warnings;

BEGIN {
  $REST::Neo4p::Agent::Mojo::UserAgent::VERSION = 0.2250;
}

our @default_headers;
our @protocols_allowed;

# LWP::UserAgent API

sub agent {
  my $self = shift;
  my ($name) = @_;
  $self->transactor->name($name) if defined $name;
  return $self->transactor->name;
}

sub credentials {
  my $self = shift;
  my ($srv, $realm, $user, $pwd) = @_;
  $self->{_user} = $user;
  $self->{_pwd} = $pwd;
  return;
}

sub default_header {
  my $self = shift;
  my ($hdr, $value) = @_;
  push @{$self->{_default_headers}}, $hdr, $value;
  return;
}

sub add_header { shift->{_default_headers}->{$_[0]} = $_[1] }
sub remove_header { delete shift->{_default_headers}->{$_[0]} }

sub protocols_allowed {
  my $self = shift;
  my ($protocols) = @_;
  push @{$self->{_protocols_allowed}}, @$protocols;
  return;
}

sub http_response {
  my ($tx) = @_;
  # kludge : if 400 error, pull the tmp file content back into response
  # body 
  if ($tx->res->is_status_class(400) && $tx->res->content->asset->is_file ) {
    $DB::single=1;
    $tx->res->body($tx->res->content->asset->slurp);
  }
  my $resp = HTTP::Response->new(
    $tx->res->code,
    $tx->res->message // $tx->res->default_message,
    [%{$tx->res->headers->to_hash}],
    $tx->res->body
   );
  return $resp;
}

sub timeout { shift->connect_timeout(@_) }

sub get { shift->_do('GET',@_) }
sub delete { shift->_do('DELETE',@_) }
sub put { shift->_do('PUT',@_) }
sub post { shift->_do('POST',@_) }

sub _do {
  my $self = shift;
  my ($rq, $url, @args) = @_;
  my ($tx, $content, $content_file);
  # neo4j wants to redirect .../data to .../data/
  # and mojo doesn't want to redirect at all...
  $self->max_redirects || $self->max_redirects(2); 
  if (length($self->{_user}) && length($self->{_pwd})) {
    $url =~ s|(https?://)|${1}$$self{_user}:$$self{_pwd}@|;
  }

  given ($rq) {
    when (/get|delete/i) {
      $tx = $self->build_tx($rq => $url => { @{$self->{_default_headers}} });
    }
    when (/post|put/i) {
      my @rm;
      for my $i (0..$#args) {
	given ($args[$i]) {
	  when ('Content') {
	    $content = $args[$i+1];
	    push @rm, $i, $i+1;
	  }
	  when (':content_file') {
	    $content_file = $args[$i+1];
	    push @rm, $i, $i+1;
	  }
	  default {
	    1;
	  }
	}
      }
      delete @args[@rm];
      my @bricks = ($rq => $url => { @{$self->{_default_headers}}, @args});
      push @bricks, json => $content if defined $content;
      $tx = $self->build_tx(@bricks);
      if (defined $content_file) {
	open my $cfh, ">", $content_file;
	$tx->res->content->unsubscribe('read')->on(
	  read => sub { $cfh->syswrite($_[1]) }
	 );
      }
    }
    default {
      REST::Neo4p::NotImplException->throw("Method $rq not implemented in ".__PACKAGE__."\n");
    }
  }
  $tx = $self->start($tx);
  if ($content_file) {
    $tx->res->content->asset(Mojo::Asset::File->new);
    $tx->res->content->asset->path($content_file);
  }
  http_response($tx);
}

1;

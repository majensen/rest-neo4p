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

our $AUTOLOAD;
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
  REST::Neo4p::NotImplException->throw("basic auth (credentials) not implemented yet\n");
}

sub default_header {
  my $self = shift;
  my ($hdr, $value) = @_;
  $hdr = lc $hdr;
  $hdr =~ tr/-/_/;
  push @{$self->{_default_headers}}, $hdr, $value;
  return;
}

sub protocols_allowed {
  my $self = shift;
  my ($protocols) = @_;
  push @{$self->{_protocols_allowed}}, @$protocols;
  return;
}

sub http_response {
  my ($tx) = @_;
  my $resp = HTTP::Response->new(
    $tx->res->code,
    $tx->res->message // $tx->res->default_message,
    [%{$tx->res->headers->to_hash}],
    $tx->res->body
   );
  return $resp;
}

sub get { shift->_do('GET',@_) }
sub delete { shift->_do('DELETE',@_) }
sub put { shift->_do('PUT',@_) }
sub post { shift->_do('POST',@_) }

sub _do {
  my $self = shift;
  my ($rq, $url, @args) = @_;
  my ($tx, $content);
  # neo4j wants to redirect .../data to .../data/
  # and mojo doesn't want to redirect at all...
  $self->max_redirects || $self->max_redirects(2); 
  given ($rq) {
    when (/get|delete/i) {
      $tx = $self->build_tx($rq => $url => { @{$self->{_default_headers}} });
    }
    when (/post|put/i) {
      for (0..$#args) {
	next unless $args[$_] eq 'Content';
	$content = delete $args[$_+1];
	delete $args[$_];
	last;
      }
      my $tx = $self->build_tx($rq => $url => { @{$self->{_default_headers}}, @args } => 
				 json => $content);
    }
    default {
      REST::Neo4p::NotImplException->throw("Method $rq not implemented in ".__PACKAGE__."\n");
    }
  }
  $tx = $self->start($tx);
  http_response($tx);
}

1;

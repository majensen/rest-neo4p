package REST::Neo4p::Agent::Mojo::UserAgent;
use base Mojo::UserAgent;
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
  $self->transactor->name($name);
  return;
}

sub default_header {
  my $self = shift;
  my ($hdr, $value) = @_;
  $hdr = lc $hdr;
  $hdr =~ tr/-/_/;
  push @default_headers, $hdr, $value;
  return;
}

sub protocols_allowed {
  my $self = shift;
  my ($protocols) = @_;
  push @protocols_allowed, @$protocols;
  return;
}

sub get {
  my $self = shift;
  my ($url) = @_;
  my $tx = $self->build_tx(GET => $url => { @default_headers });
  $tx = $self->start($tx);
  http_response($tx);
}

sub delete {
  my $self = shift;

}

sub post {
  my $self = shift;
  
}

sub put {
  my $self = shift;
}

sub http_response {
  my ($tx) = @_;
  my $resp = HTTP::Response->new(
    $tx->res->code,
    $tx->res->message // $tx->res->default_message,
    $tx->res->headers->to_hash,
    $tx->res->body
   );
  return $resp;
}

1;

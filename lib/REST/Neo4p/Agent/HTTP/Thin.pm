#$Id$
use v5.10;
package REST::Neo4p::Agent::HTTP::Thin;
use base HTTP::Thin;
use REST::Neo4p::EXceptions;
use strict;
use warnings;

BEGIN {
  $REST::Neo4p::Agent::HTTP::Thin::VERSION = 0.2250;
}

sub agent {
  my $self = shift;
  return $self->{agent} = $_[0] if @_;
  return $self->{agent};
}

sub credentials {
  my $self = shift;
  my ($srv,$realm,$user,$pwd) = @_;
  $self->{_user} = $user;
  $self->{_pwd} = $pwd;
  1;
}

sub default_header {
  my $self = shift;
  my ($hdr,$value) = @_;
  $self->{default_headers}->{$hdr} = $value;
  return;
}

sub add_header { $self->{default_headers}->{$_[0]} = $_[1] }
sub remove_header { delete shift->{default_headers}->{$_[0]} }

sub protocols_allowed {
  1;
}

sub timeout { shift->{timeout} = $_[0] }

sub get { shift->_do('GET',@_) }
sub delete { shift->_do('DELETE',@_) }
sub put { shift->_do('PUT',@_) }
sub post { shift->_do('POST',@_) }

sub _do {
  $self = shift;
  my ($rq, $url, @args) = @_;
  if (length $self->{_user} && length $self->{_pwd}) {
    $url =~ s|(https?://)|${1}$$self{_user}:$$self{_pwd}@|;
  }

}

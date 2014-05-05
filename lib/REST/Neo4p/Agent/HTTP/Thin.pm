#$Id$
use v5.10;
package REST::Neo4p::Agent::HTTP::Thin;
use base HTTP::Thin;
use URI::Escape;
use REST::Neo4p::Exceptions;
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
  $self->{_pwd} = uri_escape $pwd;
  1;
}

sub default_header {
  my $self = shift;
  my ($hdr,$value) = @_;
  $self->{default_headers}->{$hdr} = $value;
  return;
}

sub add_header { shift->{default_headers}->{$_[0]} = $_[1] }
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
  my $self = shift;
  my ($rq, $url, @args) = @_;
  if (length($self->{_user}) && length($self->{_pwd})) {
    $url =~ s|(https?://)|${1}$$self{_user}:$$self{_pwd}@|;
  }
  my ($resp,$content,$content_file);
  given ($rq) {
    when (/get|delete/i) {
      $resp = $self->request(uc $rq, $url);
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
      my %options;
      if (@args) {
	my %args = @args;
	$options{headers} = \%args;
      }

      $options{content} = $content if $content;
      if (defined $content_file) {
	open my $cfh, $content_file or die "content file : $!";
	$options{data_callback} = sub { 
	  if ($_[1]->{success}) {$cfh->syswrite($_[0])}
	};
      }
      $resp = $self->request(uc $rq, $url, \%options);
    }
    default {
      REST::Neo4p::NotImplException->throw("Method $rq not implemented in ".__PACKAGE__."\n");
    }
  }
  return $resp;
}

1;

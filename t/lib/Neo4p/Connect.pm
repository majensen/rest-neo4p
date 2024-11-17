package Neo4p::Connect;
use base Exporter;
use REST::Neo4p;
use strict;
use warnings;

our @EXPORT=qw/connect neo4j_index_unavailable/;

sub connect {
  my ($TEST_SERVER,$user,$pass) = @_;
  eval {
    REST::Neo4p->connect($TEST_SERVER,$user,$pass);
  };
  if ( my $e = REST::Neo4p::CommException->caught() ) {
    if ($e->message =~ /certificate verify failed/i) {
      REST::Neo4p->agent->ssl_opts(verify_hostname => 0); # testing only!
      REST::Neo4p->connect($TEST_SERVER,$user,$pass);
      return;
    }
    else {
      return $e;
    }
  }
  elsif ( $e = Exception::Class->caught()) {
    return $e;
  }
}

sub neo4j_index_unavailable {
  return unless REST::Neo4p->connected;
  return 'Neo4j 5 index syntax unimplemented' if REST::Neo4p->neo4j_version =~ /^5\./;
  return if REST::Neo4p->neo4j_version =~ /^[014]\./;
  return if REST::Neo4p->neo4j_version =~ /^3\.5\./;
  # For Neo4j 2 and 3 (before 3.5), only native indexes are available.
  return unless REST::Neo4p->agent->isa('REST::Neo4p::Agent::Neo4j::Driver');
  return 'Neo4j::Driver uses fulltext index for emulation, which is only available starting from Neo4j 3.5';
}

1;

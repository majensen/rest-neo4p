#-*-perl-*-
#$Id$
use Test::More tests => 4;
use Test::Exception;
use Module::Build;
use lib '../lib';
use strict;
use warnings;
no warnings qw(once);

my $build;
eval {
    $build = Module::Build->current;
};
my $TEST_SERVER = $build ? $build->notes('test_server') : 'http://127.0.0.1:7474';
my $num_live_tests = 3;

use_ok('REST::Neo4p');

my $not_connected;
eval {
  REST::Neo4p->connect($TEST_SERVER);
};
if ( my $e = REST::Neo4p::CommException->caught() ) {
  $not_connected = 1;
  diag "Test server unavailable : tests skipped";
}

SKIP : {
  skip 'no local connection to neo4j', $num_live_tests if $not_connected;
  my $AGENT = $REST::Neo4p::AGENT;
  ok $AGENT->{_actions}{node} =~ s/7474/8474/, 'change post port to 8474 (should refuse connection)';
  $REST::Neo4p::AGENT::RETRY_WAIT=1; # speed it up for test
  throws_ok { $AGENT->get_node(1) } 'REST::Neo4p::CommException';
  like $@, qr/after 3 retries/, 'error message indicates retries attempted';

  CLEANUP : {
      1;
  }
}
#$Id$

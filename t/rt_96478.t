#$Id$
use Test::More ;
use Module::Build;
use lib '../lib';
use REST::Neo4p;
use strict;
use warnings;
no warnings qw(once);
#$SIG{__DIE__} = sub { if (ref $_[0]) { $_[0]->rethrow } else { print $_[0] }};

# Test::Memory::Usage doesn't seem to play nice with skip_all...
if ($ENV{REST_NEO4P_AUTHOR_TESTS}) {

  my $build;
  my ($user,$pass);
  eval {
    $build = Module::Build->current;
    $user = $build->notes('user');
    $pass = $build->notes('pass');
  };

  my $TEST_SERVER = $build ? $build->notes('test_server') : 'http://127.0.0.1:7474';
  my $num_live_tests = 1;
  my $not_connected;

  eval {
    REST::Neo4p->connect($TEST_SERVER,$user,$pass);
  };
  if ( my $e = REST::Neo4p::CommException->caught() ) {
    $not_connected = 1;
    diag "Test server unavailable : tests skipped";
  }

  my $i;

  use Test::Memory::Usage;
  memory_usage_start;

  #subtest "many queries don't increase memory usage" => sub {
  for (1 .. 2500) {
    my $q = REST::Neo4p::Query->new(
				    'MATCH (n:Narb) return n'
				   );
    $q->execute;
    diag "$i/2500" unless ++$i % 500;
    while (my $row = $q->fetchrow_arrayref) {
      # we don't care
    };
  }
  #};
  memory_usage_ok;
}
else { 
  SKIP : {
    skip "To run author tests, set REST_NEO4P_AUTHOR_TESTS", 3;
    1;
  }
}
done_testing;

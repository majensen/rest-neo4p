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
  diag "Test server unavailable : ".$e->message;
}

SKIP : {
  skip 'no local connection to neo4j', $num_live_tests if $not_connected;
  ok my $idx = REST::Neo4p::Index->new('node', 'medicago_truncatula_3_5v5');
  is $idx->name('medicago_truncatula_3_5v5'), 'medicago_truncatula_3_5v5', 'index name is correct';

  CLEANUP : {
      ok $idx->remove, 'idx removed';
      1;
  }
}

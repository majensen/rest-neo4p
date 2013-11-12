#-*-perl-*-
#$Id$
use Test::More;
use Test::Exception;
use Module::Build;
use lib '../lib';
use strict;
use warnings;
no warnings qw(once);
my @cleanup;
use_ok('REST::Neo4p');

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

plan skip_all => "Neo4j server version >= 2.0.0-M02 required, skipping..." unless
  REST::Neo4p::_check_version(2,0,0,2);

SKIP : {
  skip 'no local connect to neo4j', $num_live_tests if $not_connected;
  1;
}

done_testing;

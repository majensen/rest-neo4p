#$Id$
use Test::More;
use Test::Exception;
use Module::Build;
use lib qw|../lib lib|;
use lib 't/lib';
use Neo4p::Connect;
use REST::Neo4p;
use strict;
use warnings;
no warnings qw(once);

my $build;
my ($user,$pass) = @ENV{qw/REST_NEO4P_TEST_USER REST_NEO4P_TEST_PASS/};
my $test_index = '828e55b1_d050_41e9_8d9e_68c25f72275c';
my ($n, $index);
eval {
    $build = Module::Build->current;
    $user = $build->notes('user');
    $pass = $build->notes('pass');
};
my $TEST_SERVER = $build ? $build->notes('test_server') : $ENV{REST_NEO4P_TEST_SERVER} // 'http://127.0.0.1:7474';

my $not_connected = connect($TEST_SERVER,$user,$pass);
diag "Test server unavailable (".$not_connected->message.") : tests skipped" if $not_connected;

plan skip_all => neo4j_index_unavailable() if neo4j_index_unavailable();
plan skip_all => 'no local connection to neo4j' if $not_connected;
plan tests => 2;

{
  $index = REST::Neo4p::Index->new('node', $test_index); 
  lives_ok {
    $n = $index->create_unique(bar => "0", {bar => "0"})
  };
  is $n->get_property('bar'),0, 'property set to 0';
}

END {
  $n && $n->remove;
  $index && $index->remove;
}

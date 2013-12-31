#$Id#
use Test::More qw/no_plan/;
use Test::Exception;
use Module::Build;
use lib '../lib';
use REST::Neo4p;
use REST::Neo4p::Schema;
use strict;
use warnings;
no warnings qw(once);

my $test_label = '79ed3b3a_515d_4f2b_89dc_9d1f0868b50c';
my @cleanup;
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


SKIP : {
  skip 'no local connection to neo4j', $num_live_tests if $not_connected;
  my $version = REST::Neo4p->neo4j_version;
  my $VERSION_OK = REST::Neo4p->_check_version(2,0);
  SKIP : {
    skip "Server version $version < 2.0", $num_live_tests unless $VERSION_OK;
    ok my $schema = REST::Neo4p::Schema->new, 'new Schema object';
    isa_ok $schema, 'REST::Neo4p::Schema';
    is $schema->_handle, REST::Neo4p->handle, 'handle correct';
    isa_ok $schema->_agent, 'REST::Neo4p::Agent';
    ok $schema->create_index($test_label,'name'), 'create name index on test label';
    is_deeply ['name'],[$schema->get_indexes($test_label)], 'name index listed';
    ok $schema->create_index($test_label => 'number'), 'create number index on test label';
    is_deeply [qw/name number/], [$schema->get_indexes($test_label)], 'both indexes now listed';
    ok $schema->create_index($test_label, 'street', 'city'), 'create multiple indexes in single call';
    is_deeply [qw/name number street city/], [$schema->get_indexes($test_label)], 'both indexes now listed';
    for (qw/name number street city/) {
      ok $schema->drop_index($test_label, $_), "drop index on '$_'";
    }
    ok !$schema->get_indexes($test_label), 'indexes gone';
    1;
  }

}

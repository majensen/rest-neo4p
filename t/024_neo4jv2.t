#$Id#
use Test::More tests => 24;
use Test::Exception;
use Module::Build;
use lib '../lib';
use strict;
use warnings;
no warnings qw(once);

#$SIG{__DIE__} = sub { print $_ };
my @cleanup;
my $build;
eval {
    $build = Module::Build->current;
};
my $TEST_SERVER = $build ? $build->notes('test_server') : 'http://127.0.0.1:7474';
my $num_live_tests = 23;

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
  my ($version) = $REST::Neo4p::AGENT->neo4j_version =~ /(^[0-9]+\.[0-9]+)/;
  my $VERSION_OK = ($version >= 2.0);
  SKIP : {
    skip "Server version $version < 2.0", $num_live_tests unless $VERSION_OK;
    ok my $n1 = REST::Neo4p::Node->new(), 'node 1';
    push @cleanup, $n1 if $n1;
    ok my $n2 = REST::Neo4p::Node->new(), 'node 2';
    push @cleanup, $n2 if $n2;
    ok !$n1->get_labels, 'node 1 has no labels yet';
    ok $n1->set_labels('mom'), 'set label on node 1';
    is_deeply [$n1->get_labels], ['mom'], 'single label is set correctly on node 1';
    ok $n1->set_labels('mom','sister'), 'set multiple labels on node 1';
    is_deeply [sort $n1->get_labels], [qw/mom sister/], 'multiple labels set correctly (and replace previous label) on node 1';
    ok $n2->set_labels('aunt','sister'), 'set multiple labels on node 2';

    ok my @sisters = REST::Neo4p->get_nodes_by_label('sister'), 'get nodes by label';
    ok ((grep {$$_ == $$n1} @sisters), 'retrieved node 1');
    ok ((grep {$$_ == $$n2} @sisters), 'retrieved node 2');
    ok my @mom = REST::Neo4p->get_nodes_by_label('mom'), 'get nodes by other label';
    ok ((grep {$$_ == $$n1} @mom), 'retrieved node 1..');
    ok (!(grep {$$_ == $$n2} @mom), '..but not node 2');
    ok $n2->add_labels('mom'), 'added other label to node 2';
    ok @mom = REST::Neo4p->get_nodes_by_label('mom'), 'get nodes by other label again';
    ok ((grep {$$_ == $$n1} @mom), 'retrieved node 1..');
    ok ((grep {$$_ == $$n2} @mom), '..and also node 2');
    ok $n1->drop_labels('mom'), 'drop other label from node 1';
    ok @mom = REST::Neo4p->get_nodes_by_label('mom'), 'get nodes by other label again';
    ok ((grep {$$_ == $$n2} @mom), 'retrieved node 2..');
    ok (!(grep {$$_ == $$n1} @mom), '..but now not node 1');
    ok $n1->drop_labels('dad'), 'ok to drop a non-existent label';


  }

}

END {

  CLEANUP : {
      $_->remove for reverse @cleanup;
  }
}

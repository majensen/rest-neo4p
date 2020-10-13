#-*-perl-*-
#$Id$
use Test::More;
use Module::Build;
use lib '../lib';
use lib 't/lib';
use Neo4p::Connect;
use strict;
use warnings;

#$SIG{__DIE__} = sub { print $_[0] };

no warnings qw(once);
my $build;
my ($user,$pass) = @ENV{qw/REST_NEO4P_TEST_USER REST_NEO4P_TEST_PASS/};

eval {
    $build = Module::Build->current;
    $user = $build->notes('user');
    $pass = $build->notes('pass');
};
my $TEST_SERVER = $build ? $build->notes('test_server') : $ENV{REST_NEO4P_TEST_SERVER} // 'http://127.0.0.1:7474';

use_ok('REST::Neo4p');

my $not_connected = connect($TEST_SERVER,$user,$pass);
diag "Test server unavailable (".$not_connected->message.") : tests skipped" if $not_connected;

sub skip_diag {
    diag 'skip' . ( defined $_[0] ? " $_[0]" : '' ) unless $ENV{'HARNESS_IS_VERBOSE'};
    skip @_;
}

SKIP : {
    skip 'no connection to neo4j' if $not_connected;

    ok my $n0 = REST::Neo4p::Node->new, 'create node 0';

    # neo4j stop ; rm -rf /path/to/graph.db ; neo4j start
    skip_diag '"relationship 0" test: only works on virgin database' unless $n0->id == 0;

    ok my $n1 = REST::Neo4p::Node->new, 'create node 1';
    ok my $r0 = REST::Neo4p::Relationship->new( $n0 => $n1, 'zero' ), 'create reln 0';

    is $r0->id, 0, 'reln 0 = 0';

    ok my $sth = REST::Neo4p::Query->new("MATCH p = ()-[]->() RETURN p"), 'create query';

    ok $sth->execute, 'execute query';
    ok my $path = $sth->fetch->[0], 'fetch path';
    ok eval { $path->relationships }, 'path contains relationship(s)';

    END {
        CLEANUP : {
	    do { note "clean up \$r0"; $r0->remove } if $r0;
	    do { note "clean up \$n0"; $n0->remove } if $n0;
	    do { note "clean up \$n1"; $n1->remove } if $n1;
        }
    }
}

done_testing;

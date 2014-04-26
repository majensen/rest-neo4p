#-*-perl-*-
#$Id$
use Test::More;
use Module::Build;
use lib '../lib';
use REST::Neo4p::Agent;
use strict;
use warnings;
plan skip_all => "Mojo::UserAgent not installed; skipping" unless eval "require Mojo::UserAgent;1";
$SIG{__DIE__} = sub { print $_[0] };
my $build;
my ($user,$pass);
eval {
    $build = Module::Build->current;
    $user = $build->notes('user');
    $pass = $build->notes('pass');
};

my $TEST_SERVER = $build ? $build->notes('test_server') : 'http://127.0.0.1:7474';

ok my $ua = REST::Neo4p::Agent->new(agent_module => 'Mojo::UserAgent');
isa_ok($ua, 'Mojo::UserAgent');
isa_ok($ua, 'REST::Neo4p::Agent');

is $TEST_SERVER, $ua->server($TEST_SERVER), 'server spec';

my $not_connected;
eval {
  $ua->credentials($TEST_SERVER, '',$user,$pass) if defined $user;
  $ua->connect;
};
if ( my $e = REST::Neo4p::CommException->caught() ) {
  $not_connected = 1;
  diag "Test server unavailable : tests skipped";
}

SKIP : {
  skip 'no local connection to neo4j',3 if $not_connected;
    is $ua->node, join('/',$TEST_SERVER, qw(db data node)), 'node url looks good';
  my ($version) = $ua->neo4j_version =~ /(^[0-9]+\.[0-9]+)/;
  cmp_ok $version, '>=', 1.8, 'Neo4j version >= 1.8 as required';
    like $ua->relationship_types, qr/^http.*types/, 'relationship types url';
}

done_testing;

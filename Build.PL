#$Id: Build.PL 17684 2012-09-23 01:12:42Z jensenma $
use Module::Build;
use strict;
use warnings;

my $build =  Module::Build->new
    ( dist_name     => 'REST-Neo4p',
      dist_abstract => 'Perl bindings for a Neo4j graph database',
      dist_version_from => 'lib/REST/Neo4p.pm',
      dist_author => 'Mark A. Jensen',
      license => 'perl',
      requires => {
	'JSON' => 2.0,
	'JSON::Streaming::Reader' => 0.05,
	'URI::Escape' => 3.3,
	'LWP::UserAgent' => 6.04,
	'Exception::Class' => 1.3
       },
      configure_requires => {
	'Module::Build' => 0
       },
      build_requires => {
	'Module::Build' => 0,
	'Test::More' => 0,
	'Test::Exception' => 0,
	'List::MoreUtils' => 0
       },
      build_recommends => {
	 'Test::Pod' => 1.0
	}
      
    );

$build->notes( test_server => $build->prompt("Server for live tests:", "http://127.0.0.1:7474"));
$build->create_build_script;

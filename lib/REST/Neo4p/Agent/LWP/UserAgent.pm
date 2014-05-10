#$Id$
package REST::Neo4p::Agent::LWP::UserAgent;
use base qw/LWP::UserAgent REST::Neo4p::Agent/;
use strict;
use warnings;
BEGIN {
  $REST::Neo4p::Agent::LWP::UserAgent::VERSION = "0.2250";
}
sub add_header { shift->default_headers->header(@_) }
sub remove_header { shift->default_headers->remove_header($_[0]) }
1;

# -*- perl -*-
#$Id: 001_load.t 17590 2012-08-27 03:47:45Z jensenma $


# t/001_load.t - check module loading and create testing directory

use Test::More tests => 1;

BEGIN { use_ok( 'REST::Neo4p' ); }




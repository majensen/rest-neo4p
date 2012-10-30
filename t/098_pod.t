#-*-perl-*-
#$Id: 098_pod.t 17640 2012-08-30 13:46:38Z jensenma $
use Test::More;
use Module::Build;
eval "use Test::Pod 1.00";
plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;
plan skip_all => "Not calling from build process" unless Module::Build->current;
all_pod_files_ok();

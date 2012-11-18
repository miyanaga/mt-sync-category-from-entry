use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib $Bin;
use MTPath;

use MT;
my $mt = MT->new(Config => test_config) or die MT->errstr;

use_ok 'MT::SyncCategoryFromEntry::Util';
use_ok 'MT::SyncCategoryFromEntry::Core';
use_ok 'MT::SyncCategoryFromEntry::CMS';

done_testing;
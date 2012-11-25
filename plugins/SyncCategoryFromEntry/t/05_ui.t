use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib $Bin;
use MTPath;
use Data::Dumper;

use MT;
my $mt = MT->new(Config => test_config) or die MT->errstr;

use MT::Plugins::Test::Object;
use MT::Plugins::Test::Request::CMS;
use MT::SyncCategoryFromEntry::Util;

sub count_sync_categories {
    my $blog = shift;

    my $count = 0;
    if ( my $iter = MT->model('category')->load_iter({
        blog_id => $blog->id,
    })) {
        while ( my $category = $iter->() ) {
            $count ++ if $category->category_sync_entry_id;
        }
    }

    $count;
}

test_common_website(
    as_superuser => 1,
    test => sub {
        my ( $website, $sync_from, $author, $password ) = @_;

        test_objects(
            model => 'blog',
            template => 'common_blog',
            values => {
                sync_to => {
                    name => 'Sync To',
                    parent_id => $website->id,
                },
                sync_also => {
                    name => 'Sync Also',
                    parent_id => $website->id,
                },
                no_effort => {
                    name => 'No Effort',
                    parent_id => $website->id,
                },
            },
            test => sub {
                my $objects = shift;
                my $sync_to = $objects->{sync_to};
                my $no_effort = $objects->{no_effort};
                my $sync_also = $objects->{sync_also};

                my $cms = 'MT::Plugins::Test::Request::CMS';
                $cms->test_user_mech(
                    as_superuser => 1,
                    via => 'bootstrap',
                    test => sub {
                        my $mech = shift;

                        subtest 'Edit screen' => sub {
                            my $res = $mech->get($cms->uri( __mode => 'sync_category_from_entry_edit', blog_id => $sync_to->id ));
                            like $res->content, qr/sync-category-from-entry/;
                            like $res->content, qr/name="sync-category-from-entry-form"/;
                        };

                    },
                );
            },
        );
    },
);

done_testing;
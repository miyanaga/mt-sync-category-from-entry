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
use MT::Plugins::Test::Template;
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
                },
                sync_also => {
                    name => 'Sync Also',
                },
                no_effort => {
                    name => 'No Effort',
                },
            },
            test => sub {
                my $objects = shift;
                my $sync_to = $objects->{sync_to};
                my $no_effort = $objects->{no_effort};
                my $sync_also = $objects->{sync_also};

                for my $b ( $sync_to, $sync_also ) {
                    $b->category_sync_entry_from($sync_from->id);
                    $b->category_sync_entry_force_update(1);
                    $b->category_sync_entry_force_remove(1);
                    $b->save;
                }

                my %values = map {
                    (
                        "entry$_" => {
                            _model => 'entry',
                            _template => 'common_entry',
                            basename => "basename$_",
                            title => "Entry$_",
                            blog_id => $sync_from->id,
                            text => "Text$_",
                        },
                        "category$_" => {
                            _model => 'category',
                            _template => 'common_category',
                            basename => "basename$_",
                            label => "Category$_",
                            blog_id => $no_effort->id,
                        }
                    )
                } (1, 2);

                test_objects(
                    model => 'entry',
                    template => 'common_entry',
                    values => \%values,
                    test => sub {
                        my $objects = shift;

                        subtest 'Check sync' => sub {
                            is count_sync_categories($sync_to), 2;
                            is count_sync_categories($sync_also), 2;
                            is count_sync_categories($no_effort), 0;
                        };

                        subtest 'Unsync sync to' => sub {
                            $sync_to->category_sync_entry_from(0);
                            $sync_to->save;

                            is count_sync_categories($sync_to), 0;
                            is count_sync_categories($sync_also), 2;
                            is count_sync_categories($no_effort), 0;
                        };

                        subtest 'Unsync sync also' => sub {
                            $sync_also->category_sync_entry_from(0);
                            $sync_also->save;
                            
                            is count_sync_categories($sync_to), 0;
                            is count_sync_categories($sync_also), 0;
                            is count_sync_categories($no_effort), 0;
                        };
                    }
                );
            },
        );
    },
);

done_testing;
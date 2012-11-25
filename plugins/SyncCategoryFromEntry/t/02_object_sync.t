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
use MT::SyncCategoryFromEntry::Util;

sub test_sync_result {
    my ( $blogs, $test, $subtest_label ) = @_;
    $subtest_label ||= 'State of sync to and sync also';

    subtest 'No effort' => sub {
        # No effort blog always no entries and no categories
        my $entry_count_in_no_effort = MT->model('entry')->count({ blog_id => $blogs->{no_effort}->id, class => 'entry' });
        my $category_count_in_no_effort = MT->model('category')->count({ blog_id => $blogs->{no_effort}->id, class => 'category' });
        is $entry_count_in_no_effort, 0, 'No effort to entries';
        is $category_count_in_no_effort, 0, 'No effort to categories';
    };

    # About sync from
    subtest $subtest_label => sub {
        my @entries = MT->model('entry')->load(
            { blog_id => $blogs->{sync_from}->id, class => 'entry' },
            { sort => 'basename' }
        );
        my %entries = map { $_->basename => $_ } @entries;
        my @entry_basenames = map { $_->basename } @entries;
        my @entry_titles = map { $_->title } @entries;

        # About sync to
        my @categories = MT->model('category')->load(
            { blog_id => $blogs->{sync_to}->id, class => 'category', parent => 0 },
            { sort => 'basename' }
        );

        my %categories = map { $_->basename => $_ } @categories;

        my @category_basenames = map { $_->basename } @categories;
        my @category_labels = map { $_->label } @categories;

        # About sync also
        my @also_categories = MT->model('category')->load(
            { blog_id => $blogs->{sync_also}->id, class => 'category', parent => 0 },
            { sort => 'basename' }
        );

        my %also_categories = map { $_->basename => $_ } @also_categories;

        my @also_category_basenames = map { $_->basename } @also_categories;
        my @also_category_labels = map { $_->label } @also_categories;

        $test->(
            sync_from => $blogs->{sync_from},
            sync_to => $blogs->{sync_to},
            sync_also => $blogs->{sync_also},
            no_effort => $blogs->{no_effort},

            entries => \%entries,
            entry_basenames => \@entry_basenames,
            entry_titles => \@entry_titles,

            categories => \%categories,
            category_basenames => \@category_basenames,
            category_labels => \@category_labels,

            also_categories => \%also_categories,
            also_category_basenames => \@also_category_basenames,
            also_category_labels => \@also_category_labels,
        );
    };
}

sub by_parameters {
    my %tupple = @_;

    # Tests

    # Test for resync all
    my $before_resync = $tupple{before_resync};
    my $after_resync = $tupple{after_resync};

    # Incremental tests for CURD
    my $after_incremental_add = $tupple{after_incremental_add};
    my $after_incremental_update_title = $tupple{after_incremental_update_title};
    my $after_incremental_update_basename = $tupple{after_incremental_update_basename};
    my $after_incremental_unpublish_first = $tupple{after_incremental_unpublish_first};
    my $after_incremental_remove = $tupple{after_incremental_remove};

    # Create common website and blog to sync from
    test_common_website(
        as_superuser => 1,
        test => sub {
            my ( $website, $sync_from, $author, $password ) = @_;

            # Create blog sync to, sync to also and no efforts.
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
                    my $blogs = shift;
                    my %testing_blogs = (
                        %$blogs,
                        sync_from => $sync_from,
                    );

                    my $sync_to = $blogs->{sync_to};
                    my $sync_also = $blogs->{sync_also};
                    my $no_effort = $blogs->{no_effort};

                    # Testing
                    subtest 'Resync' => sub {
                        # 3 entries in sync_from: basename1..3
                        my %values = map {
                            my $value = {
                                blog_id => $sync_from->id,
                                author_id => $author->id,
                                title => "Entry$_",
                                basename => "basename$_",
                            };
                            ( "entry$_" => $value );
                        } (1,2,3);

                        test_objects(
                            model => 'entry',
                            template => 'common_entry',
                            values => \%values,
                            test => sub {
                                my $entries = shift;

                                # 3 categories in sync_to: basename2..4
                                my %values = map {
                                    ( "category$_" => {
                                        blog_id => $sync_to->id,
                                        label => "Category$_",
                                        basename => "basename$_",
                                    } );
                                } (2, 3, 4);

                                test_objects(
                                    model => 'category',
                                    template => 'common_category',
                                    values => \%values,
                                    test => sub {
                                        my $categories = shift;

                                        # Create child categories: shoud be ignored
                                        for my $c ( values %$categories ) {
                                            my $new = MT->model('category')->new;
                                            $new->set_values({
                                                allow_pings => 0,
                                                author_id => $author->id,
                                                basename => $c->basename,
                                                class => 'category',
                                                description => '',
                                                label => 'ChildOf' . $c->label,
                                                parent => $c->id,
                                                ping_urls => '',
                                            });
                                            $new->save;
                                        }

                                        # Setup sync_to blog from args
                                        subtest 'Resync tests' => sub {
                                            $sync_to->category_sync_entry_from($sync_from->id);
                                            $sync_to->category_sync_entry_force_update($tupple{force_update});
                                            $sync_to->category_sync_entry_force_remove($tupple{force_remove});
                                            $sync_to->save;

                                            # Test atate before resync one blog
                                            test_sync_result(\%testing_blogs, $before_resync, 'Before resync');

                                            # Run resync
                                            resync_blog($sync_to, $author);

                                            # Test state after resync one blog
                                            test_sync_result(\%testing_blogs, $after_resync, 'After resync');
                                        };

                                        # Incremental tests

                                        subtest 'Incremental add/update/remove' => sub {
                                            # Setup sync_also blog from args
                                            $sync_also->category_sync_entry_from($sync_from->id);
                                            $sync_also->category_sync_entry_force_update($tupple{force_update});
                                            $sync_also->category_sync_entry_force_remove($tupple{force_remove});
                                            $sync_also->save;

                                            # Add 2 entries
                                            my %entries = map {
                                                (
                                                    "basename$_" => {
                                                        blog_id => $sync_from->id,
                                                        author_id => $author->id,
                                                        title => "Entry$_",
                                                        basename => "basename$_",
                                                    }
                                                )
                                            } (5, 6);

                                            test_objects(
                                                model => 'entry',
                                                template => 'common_entry',
                                                values => \%entries,
                                                test => sub {
                                                    my $added = shift;

                                                    test_sync_result(\%testing_blogs, $after_incremental_add, 'After add entries 5, 6');

                                                    # Change each title
                                                    for my $e ( values %$added ) {
                                                        my $title = $e->title;
                                                        $title =~ s/Entry/Changed/i;
                                                        $e->title($title);
                                                        $e->save;
                                                    }
                                                    test_sync_result(\%testing_blogs, $after_incremental_update_title, 'After uppdate entries title');

                                                    # Change each basename
                                                    for my $e ( values %$added ) {
                                                        my $basename = $e->basename;
                                                        $basename =~ s/basename/changed/i;
                                                        $e->basename($basename);
                                                        $e->save;
                                                    }
                                                    test_sync_result(\%testing_blogs, $after_incremental_update_basename, 'After update entries basename');

                                                    # Change state of first added to unpublish
                                                    my $e = (values %$added)[0];
                                                    $e->status(MT::Entry::HOLD());
                                                    $e->save;
                                                    test_sync_result(\%testing_blogs, $after_incremental_unpublish_first, 'After unpublish the first entry');
                                                },
                                            );

                                            # After test objects, added entries are removed.
                                            test_sync_result(\%testing_blogs, $after_incremental_remove);
                                        };
                                    },
                                );
                            }
                        );
                    };
                }
            );
        },
    );
}

subtest 'No update and no remove' => sub {
    by_parameters(
        force_update => 0,
        force_remove => 0,
        before_resync => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename2 basename3 basename4/];
            is_deeply $args{category_labels}, [qw/Category2 Category3 Category4/];
            is_deeply $args{also_category_basenames}, [];
            is_deeply $args{also_category_labels}, [];
        },
        after_resync => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4/];
            is_deeply $args{category_labels}, [qw/Entry1 Category2 Category3 Category4/];
            is_deeply $args{also_category_basenames}, [];
            is_deeply $args{also_category_labels}, [];
        },
        after_incremental_add => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4 basename5 basename6/];
            is_deeply $args{category_labels}, [qw/Entry1 Category2 Category3 Category4 Entry5 Entry6/];
            is_deeply $args{also_category_basenames}, [qw/basename5 basename6/];
            is_deeply $args{also_category_labels}, [qw/Entry5 Entry6/];
        },
        after_incremental_update_title => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4 basename5 basename6/];
            is_deeply $args{category_labels}, [qw/Entry1 Category2 Category3 Category4 Entry5 Entry6/];
            is_deeply $args{also_category_basenames}, [qw/basename5 basename6/];
            is_deeply $args{also_category_labels}, [qw/Entry5 Entry6/];
        },
        after_incremental_update_basename => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4 basename5 basename6/];
            is_deeply $args{category_labels}, [qw/Entry1 Category2 Category3 Category4 Entry5 Entry6/];
            is_deeply $args{also_category_basenames}, [qw/basename5 basename6/];
            is_deeply $args{also_category_labels}, [qw/Entry5 Entry6/];
        },
        after_incremental_unpublish_first => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4 basename5 basename6/];
            is_deeply $args{category_labels}, [qw/Entry1 Category2 Category3 Category4 Entry5 Entry6/];
            is_deeply $args{also_category_basenames}, [qw/basename5 basename6/];
            is_deeply $args{also_category_labels}, [qw/Entry5 Entry6/];
        },
        after_incremental_remove => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4 basename5 basename6/];
            is_deeply $args{category_labels}, [qw/Entry1 Category2 Category3 Category4 Entry5 Entry6/];
            is_deeply $args{also_category_basenames}, [qw/basename5 basename6/];
            is_deeply $args{also_category_labels}, [qw/Entry5 Entry6/];
        },
    );
};

subtest 'No update and do remove' => sub {
    by_parameters(
        force_update => 0,
        force_remove => 1,
        before_resync => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename2 basename3 basename4/];
            is_deeply $args{category_labels}, [qw/Category2 Category3 Category4/];
            is_deeply $args{also_category_basenames}, [];
            is_deeply $args{also_category_labels}, [];
        },
        after_resync => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4/];
            is_deeply $args{category_labels}, [qw/Entry1 Category2 Category3 Category4/];
            is_deeply $args{also_category_basenames}, [];
            is_deeply $args{also_category_labels}, [];
        },
        after_incremental_add => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4 basename5 basename6/];
            is_deeply $args{category_labels}, [qw/Entry1 Category2 Category3 Category4 Entry5 Entry6/];
            is_deeply $args{also_category_basenames}, [qw/basename5 basename6/];
            is_deeply $args{also_category_labels}, [qw/Entry5 Entry6/];
        },
        after_incremental_update_title => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4 basename5 basename6/];
            is_deeply $args{category_labels}, [qw/Entry1 Category2 Category3 Category4 Entry5 Entry6/];
            is_deeply $args{also_category_basenames}, [qw/basename5 basename6/];
            is_deeply $args{also_category_labels}, [qw/Entry5 Entry6/];
        },
        after_incremental_update_basename => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4 basename5 basename6/];
            is_deeply $args{category_labels}, [qw/Entry1 Category2 Category3 Category4 Entry5 Entry6/];
            is_deeply $args{also_category_basenames}, [qw/basename5 basename6/];
            is_deeply $args{also_category_labels}, [qw/Entry5 Entry6/];
        },
        after_incremental_unpublish_first => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4 basename6/];
            is_deeply $args{category_labels}, [qw/Entry1 Category2 Category3 Category4 Entry6/];
            is_deeply $args{also_category_basenames}, [qw/basename6/];
            is_deeply $args{also_category_labels}, [qw/Entry6/];
        },
        after_incremental_remove => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4/];
            is_deeply $args{category_labels}, [qw/Entry1 Category2 Category3 Category4/];
            is_deeply $args{also_category_basenames}, [];
            is_deeply $args{also_category_labels}, [];
        },
    );
};

subtest 'Update and no remove' => sub {
    by_parameters(
        force_update => 1,
        force_remove => 0,
        before_resync => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename2 basename3 basename4/];
            is_deeply $args{category_labels}, [qw/Category2 Category3 Category4/];
            is_deeply $args{also_category_basenames}, [];
            is_deeply $args{also_category_labels}, [];
        },
        after_resync => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4/];
            is_deeply $args{category_labels}, [qw/Entry1 Entry2 Entry3 Category4/];
            is_deeply $args{also_category_basenames}, [];
            is_deeply $args{also_category_labels}, [];
        },
        after_incremental_add => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4 basename5 basename6/];
            is_deeply $args{category_labels}, [qw/Entry1 Entry2 Entry3 Category4 Entry5 Entry6/];
            is_deeply $args{also_category_basenames}, [qw/basename5 basename6/];
            is_deeply $args{also_category_labels}, [qw/Entry5 Entry6/];
        },
        after_incremental_update_title => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4 basename5 basename6/];
            is_deeply $args{category_labels}, [qw/Entry1 Entry2 Entry3 Category4 Changed5 Changed6/];
            is_deeply $args{also_category_basenames}, [qw/basename5 basename6/];
            is_deeply $args{also_category_labels}, [qw/Changed5 Changed6/];
        },
        after_incremental_update_basename => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4 changed5 changed6/];
            is_deeply $args{category_labels}, [qw/Entry1 Entry2 Entry3 Category4 Changed5 Changed6/];
            is_deeply $args{also_category_basenames}, [qw/changed5 changed6/];
            is_deeply $args{also_category_labels}, [qw/Changed5 Changed6/];
        },
        after_incremental_unpublish_first => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4 changed5 changed6/];
            is_deeply $args{category_labels}, [qw/Entry1 Entry2 Entry3 Category4 Changed5 Changed6/];
            is_deeply $args{also_category_basenames}, [qw/changed5 changed6/];
            is_deeply $args{also_category_labels}, [qw/Changed5 Changed6/];
        },
        after_incremental_remove => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4 changed5 changed6/];
            is_deeply $args{category_labels}, [qw/Entry1 Entry2 Entry3 Category4 Changed5 Changed6/];
            is_deeply $args{also_category_basenames}, [qw/changed5 changed6/];
            is_deeply $args{also_category_labels}, [qw/Changed5 Changed6/];
        },
    );
};

subtest 'Update and remove' => sub {
    by_parameters(
        force_update => 1,
        force_remove => 1,
        before_resync => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename2 basename3 basename4/];
            is_deeply $args{category_labels}, [qw/Category2 Category3 Category4/];
            is_deeply $args{also_category_basenames}, [];
            is_deeply $args{also_category_labels}, [];
        },
        after_resync => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4/];
            is_deeply $args{category_labels}, [qw/Entry1 Entry2 Entry3 Category4/];
            is_deeply $args{also_category_basenames}, [];
            is_deeply $args{also_category_labels}, [];
        },
        after_incremental_add => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4 basename5 basename6/];
            is_deeply $args{category_labels}, [qw/Entry1 Entry2 Entry3 Category4 Entry5 Entry6/];
            is_deeply $args{also_category_basenames}, [qw/basename5 basename6/];
            is_deeply $args{also_category_labels}, [qw/Entry5 Entry6/];
        },
        after_incremental_update_title => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4 basename5 basename6/];
            is_deeply $args{category_labels}, [qw/Entry1 Entry2 Entry3 Category4 Changed5 Changed6/];
            is_deeply $args{also_category_basenames}, [qw/basename5 basename6/];
            is_deeply $args{also_category_labels}, [qw/Changed5 Changed6/];
        },
        after_incremental_update_basename => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4 changed5 changed6/];
            is_deeply $args{category_labels}, [qw/Entry1 Entry2 Entry3 Category4 Changed5 Changed6/];
            is_deeply $args{also_category_basenames}, [qw/changed5 changed6/];
            is_deeply $args{also_category_labels}, [qw/Changed5 Changed6/];
        },
        after_incremental_unpublish_first => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4 changed6/];
            is_deeply $args{category_labels}, [qw/Entry1 Entry2 Entry3 Category4 Changed6/];
            is_deeply $args{also_category_basenames}, [qw/changed6/];
            is_deeply $args{also_category_labels}, [qw/Changed6/];
        },
        after_incremental_remove => sub {
            my %args = @_;
            is_deeply $args{category_basenames}, [qw/basename1 basename2 basename3 basename4/];
            is_deeply $args{category_labels}, [qw/Entry1 Entry2 Entry3 Category4/];
            is_deeply $args{also_category_basenames}, [];
            is_deeply $args{also_category_labels}, [];
        },
    );
};

done_testing;

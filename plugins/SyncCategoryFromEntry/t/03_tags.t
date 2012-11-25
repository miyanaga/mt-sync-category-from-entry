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
                            my @sync_to_labels = map {
                                $_->label,
                            } MT->model('category')->load({
                                blog_id => $sync_to->id,
                                class => 'category',
                            }, { sort => 'basename' });

                            is_deeply \@sync_to_labels, [qw/Entry1 Entry2/];

                            my @sync_also_labels = map {
                                $_->label,
                            } MT->model('category')->load({
                                blog_id => $sync_to->id,
                                class => 'category',
                            }, { sort => 'basename' });

                            is_deeply \@sync_also_labels, [qw/Entry1 Entry2/];

                            my @not_sync_labels = map {
                                $_->label,
                            } MT->model('category')->load({
                                blog_id => $no_effort->id,
                                class => 'category',
                            }, { sort => 'basename' });

                            is_deeply \@not_sync_labels, [qw/Category1 Category2/];
                        };

                        subtest 'Blog sync to' => sub {
                            my $category = MT->model('category')->load({
                                blog_id => $sync_to->id,
                                basename => 'basename1',
                            });
                            my %stash = (
                                blog => $sync_to,
                                blog_id => $sync_to->id,
                                category => $category,
                            );

                            test_template(
                                stash => \%stash,
                                template => q{<mt:CategorySyncEntry><mt:BlogName>/<mt:EntryBody></mt:CategorySyncEntry>},
                                test => sub {
                                    my %args = @_;
                                    is $args{result}, q{Test Blog/Text1};
                                },
                            );

                            test_template(
                                stash => \%stash,
                                template => q{<mt:IfCategorySyncFromEntry>true<mt:Else>false</mt:IfCategorySyncFromEntry>},
                                test => sub {
                                    my %args = @_;
                                    is $args{result}, 'true';
                                },
                            );
                        };

                        subtest 'Blog sync from' => sub {
                            my $entry = $objects->{entry1};
                            my %stash = (
                                blog => $sync_from,
                                blog_id => $sync_from->id,
                                entry => $entry,
                            );

                            test_template(
                                stash => \%stash,
                                template => q{<mt:EntrySyncCategories glue=","><mt:BlogName>/<mt:CategoryLabel></mt:EntrySyncCategories>},
                                test => sub {
                                    my %args = @_;
                                    diag $args{error};
                                    is $args{result}, 'Sync Also/Entry1,Sync To/Entry1';
                                }
                            );
                        };

                        subtest 'No effort' => sub {
                            my $category = MT->model('category')->load({
                                blog_id => $no_effort->id,
                                basename => 'basename1',
                            });
                            my %stash = (
                                blog => $sync_to,
                                blog_id => $sync_to->id,
                                category => $category,
                            );

                            test_template(
                                stash => \%stash,
                                template => q{<mt:CategorySyncEntry><mt:BlogName>/<mt:EntryBody></mt:CategorySyncEntry>},
                                test => sub {
                                    my %args = @_;
                                    is $args{result}, q{};
                                },
                            );

                            test_template(
                                stash => \%stash,
                                template => q{<mt:IfCategorySyncFromEntry>true<mt:Else>false</mt:IfCategorySyncFromEntry>},
                                test => sub {
                                    my %args = @_;
                                    is $args{result}, 'false';
                                },
                            );
                        };
                    }
                );
            },
        );
    },
);

done_testing;
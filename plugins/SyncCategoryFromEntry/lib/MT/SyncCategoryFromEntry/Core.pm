package MT::SyncCategoryFromEntry::Core;

use strict;
use warnings;
use MT::SyncCategoryFromEntry::Util;

sub sync_to_blogs {
    my ( $entry, $proc ) = @_;
    my $sync_from = $entry->blog || return 1;

    my @sync_tos = MT->model('blog')->load({
        category_sync_entry_from => $sync_from->id,
    });

    for my $sync_to ( @sync_tos ) {
        next if $sync_to->id == $sync_from->id;
        $proc->($sync_from, $sync_to, $entry);
    }

    1;
}

sub on_entry_saved {
    my ( $cb, $eh, $entry ) = @_;

    return sync_to_blogs( $entry, sub {
        my ( $sync_from, $sync_to, $entry ) = @_;
        sync_category_from_entry(
            sync_from => $sync_from,
            sync_to => $sync_to,
            entry => $entry,
        );
    });
}

sub on_entry_removed {
    my ( $cb, $eh, $entry ) = @_;

    return sync_to_blogs($entry, sub {
        my ( $sync_from, $sync_to, $entry ) = @_;
        my @categories = MT->model('category')->load({
            blog_id => $sync_to->id,
            category_sync_entry_id => $entry->id,           
        });

        sync_category_from_entry(
            sync_from => $sync_from,
            sync_to => $sync_to,
            entry => 0,
            category => $_
        ) foreach @categories;
    });

    1;
}

1;
__END__
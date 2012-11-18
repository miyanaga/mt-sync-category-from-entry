package MT::SyncCategoryFromEntry::Util;

use strict;
use warnings;
use base 'Exporter';
use MT;
use MT::Entry;

our @EXPORT = qw(plugin sync_category_from_entry resync_blog);

sub plugin {
    MT->component('synccategoryfromentry');
}

sub sync_category_from_entry {
    my %args = @_;

    my $sync_to = $args{sync_to} || return;
    my $sync_from = $args{sync_from};
    my $category = $args{category};
    my $entry = $args{entry};
    my $author = $args{author};
    my $force_update = $args{force_update};
    my $force_remove = $args{force_remove};

    # Try to get entry and category
    if ( !defined($entry) && $category ) {
        $entry = MT->model('entry')->load($category->category_sync_entry_id)
            if $category->category_sync_entry_id;
    } elsif ( !defined($category) && $entry ) {
        $category = MT->model('category')->load({
            blog_id => $sync_to->id,
            category_sync_entry_id => $entry->id,
        }) if $entry->id;
    }

    # Nothing to do if both of category and entry not exist - invalid param
    return if !$category && !$entry;

    # Try to get author
    $author = $entry->author if !defined($author) && $entry;

    # Try to get sync_from
    unless ( $sync_from ) {
        my $sync_from_id = $sync_to->category_sync_entry_from || return;
        $sync_from = MT->model('blog')->load($sync_from_id) || return;
    }

    # Get update/remove policy from blog column if not passed
    $force_update = $sync_to->category_sync_entry_force_update
        unless defined $force_update;
    $force_remove = $sync_to->category_sync_entry_force_remove
        unless defined $force_remove;

    # Delete category if category exists but entry not exists
    if ( $category && ( !$entry || $entry->status != MT::Entry::RELEASE() ) ) {
        $category->remove if $force_remove;
        return;
    }

    # Ensure entry and category pair
    # Create a new category
    if ( $category ) {
        return unless $force_update;
    } else {
        $category = MT->model('category')->new;

        $category->set_values({
            blog_id => $sync_to->id,
            allow_pings => $sync_to->allow_pings_default || 0,
            author_id => $author ? $author->id : 0,
            class => 'category',
            description => '',
            parent => 0,
            ping_urls => '',
            created_by => $author ? $author->id : 0,
        });
    }

    # Which entry column become category description?
    my $description_from = $args{description_from}
        || $sync_to->category_sync_description_from;
    my $description = $description_from
        && $entry->has_column($description_from)
        && $entry->$description_from || '';

    # Update category columns
    $category->set_values({
        label => $entry->title || plugin->translate('No Title'),
        basename => $entry->basename,
        description => $description,
        category_sync_entry_id => $entry->id,
    });

    $category->save;
    $category;
}

sub resync_blog {
    my ( $sync_to, $author ) = @_;

    my $sync_from_id = $sync_to->category_sync_entry_from || return;
    my $sync_from = MT->model('blog')->load($sync_from_id) || return;
    my %opts = (
        sync_to => $sync_to,
        sync_from => $sync_from,
        force_update => $sync_to->category_sync_entry_force_update || 0,
        force_remove => $sync_to->category_sync_entry_force_remove || 0,
        description_from => $sync_to->category_sync_description_from || '',
    );

    my @entries = MT->model('entry')->load({
        blog_id => $sync_from->id,
        class => 'entry',
    });
    my %entries_by_id = map { $_->id => $_ } @entries;
    my %entries_by_basename = map { $_->basename => $_ } @entries;
    my @categories = MT->model('category')->load({
        blog_id => $sync_to->id,
        class => 'category',
        parent => 0,
    });
    my %categories_by_id = map { $_->id => $_ } @categories;

    # Update or remove category
    CATEGORY: for my $cid ( keys %categories_by_id ) {
        my $c = $categories_by_id{$cid};
        my $e;

        if ( my $eid = $c->category_sync_entry_id ) {
            $e = $entries_by_id{$eid};
        } else {
            $e = $entries_by_basename{$c->basename};
        }

        if ( $e && $e->status == MT::Entry::RELEASE() ) {
            local $opts{category} = $c;
            local $opts{entry} = $e;

            sync_category_from_entry(%opts);

            delete $entries_by_id{$e->id};
            delete $entries_by_basename{$e->basename};
            delete $categories_by_id{$cid};
            next CATEGORY;
        }

        {
            local $opts{category} = $e;
            local $opts{entry} = 0;

            delete $categories_by_id{$cid};
            sync_category_from_entry(%opts);
        }
    }

    # Create category from entry
    ENTRY: for my $eid ( keys %entries_by_id ) {
        my $e = $entries_by_id{$eid} || next ENTRY;
        $e->status == MT::Entry::RELEASE() || next ENTRY;

        local $opts{entry} = $e;
        local $opts{category} = 0;

        sync_category_from_entry(%opts);
    }

}

1;
__END__

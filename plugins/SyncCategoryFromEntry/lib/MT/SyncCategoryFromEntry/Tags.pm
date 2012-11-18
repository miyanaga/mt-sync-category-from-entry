package MT::SyncCategoryFromEntry::Tags;

use strict;
use MT;
use MT::Entry;
use MT::SyncCategoryFromEntry::Util;

sub bad_category_context {
    my ( $ctx, $tag ) = @_;
    return $ctx->error(
        plugin->translate('You used an \'[_1]\' tag outside of the context of a category', $tag)
    );
}

sub bad_entry_context {
    my ( $ctx, $tag ) = @_;
    return $ctx->error(
        plugin->translate('You used an \'[_1]\' tag outside of the context of an entry; Perhaps you mistakenly placed it outside of an \'MTEntries\' container tag?', $tag)
    );
}

sub hdlr_if_category_sync_from_entry {
    my ( $ctx, $args, $cond ) = @_;
    my $category = $ctx->stash('category')
        or return bad_category_context($ctx, 'mtIfCategorySyncFromEntry');

    # Return false if not sync
    return 0 unless $category->category_sync_entry_id;

    # Category blog
    my $blog = MT->model('blog')->load($category->blog_id)
        or return 0;

    # Return true if sync to entry and the entry published
    my $entry = MT->model('entry')->load({
        id => $category->category_sync_entry_id,
        blog_id => $blog->category_sync_entry_from,
        status => MT::Entry::RELEASE(),
    });

    $entry && $entry->status == MT::Entry::RELEASE() ? 1 : 0;
}

sub hdlr_category_sync_entry {
    my ( $ctx, $args, $cond ) = @_;
    my $category = $ctx->stash('category')
        or return bad_category_context($ctx, 'mtCategorySyncEntry');

    # Category blog
    my $blog = MT->model('blog')->load($category->blog_id)
        or return '';

    # Return empty if not sync or sync entry not published
    my $entry = MT->model('entry')->load({
        id => $category->category_sync_entry_id,
        blog_id => $blog->category_sync_entry_from,
        status => MT::Entry::RELEASE(),
    }) or return '';

    # Switch context
    my $stay_blog_context = $args->{stay_blog_context};
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    local $ctx->{__stash}->{entry} = $entry;
    local $ctx->{__stash}->{blog} = $stay_blog_context
        ? $ctx->{__stash}->{blog}
        : $entry->blog;
    local $ctx->{__stash}->{blog_id} = $stay_blog_context
        ? $ctx->{__stash}->{blog_id}
        : $entry->blog->id;

    # Build inside
    defined ( my $out = $builder->build( $ctx, $tokens, $cond ) )
        or return $ctx->error( $builder->errstr );
    $out;
}

sub hdlr_entry_sync_categories {
    my ( $ctx, $args, $cond ) = @_;
    my $entry = $ctx->stash('entry')
        or return bad_entry_context($ctx, 'mtEntrySyncCategories');

    # Blog ids sync to
    my @blog_ids = map {
        $_->id
    } MT->model('blog')->load({
        category_sync_entry_from => $entry->blog->id,
    }, { fetchonly => [qw/id category_sync_entry_from/] });

    # Build inside
    my $res = '';
    my $glue = $args->{glue};
    my $stay_blog_context = $args->{stay_blog_context};
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    my $iter = MT->model('category')->load_iter({
        category_sync_entry_id => $entry->id,
        blog_id => \@blog_ids,
    }, { sort => 'blog_id' }) || return $ctx->error(MT->model('category')->errstr);

    while ( my $category = $iter->() ) {

        # Switch context
        my $blog = MT->model('blog')->load($category->blog_id) || next;
        local $ctx->{__stash}->{category} = $category;
        local $ctx->{inside_mt_categories} = 1;
        local $ctx->{__stash}->{blog} = $stay_blog_context
            ? $ctx->{__stash}->{blog}
            : $blog;
        local $ctx->{__stash}->{blog_id} = $stay_blog_context
            ? $ctx->{__stash}->{blog_id}
            : $blog->id;

        # Build each
        defined ( my $out = $builder->build( $ctx, $tokens, $cond ) )
            or return $ctx->error( $builder->errstr );
        $res .= $glue if defined $glue && length($res) && length($out);
        $res .= $out;
    }

    $res;
}

1;
__END__
package MT::SyncCategoryFromEntry::CMS;

use strict;
use warnings;

use MT::SyncCategoryFromEntry::Util;

sub on_template_param_list_category {
    my ( $cb, $app, $param, $tmpl ) = @_;

    my $blog = $app->blog || return 1;
    my $sync_from_id = $blog->category_sync_entry_from || return 1;
    my $sync_from = MT->model('blog')->load($sync_from_id) || return 1;
    return 1 unless $sync_from->is_blog;

    my $name = plugin->translate('[_1] &ratuo; [_2]', $sync_from->name, $sync_from->website->name);
    $param->{sync_category_from_entry_info} = plugin->translate(
        'Categories in this blog will be synchronized from entries in "[_1]"', $name
    );

    my $content_header = $tmpl->createElement('setvarblock', { name => 'content_header', append => 1 });
    $content_header->innerHTML(q{
<__trans_section component="synccategoryfromentry">
<mtapp:statusmsg
    id="sync-category-from-entry-info"
    class="info"
    can_close="0">
<mt:var name="sync_category_from_entry_info">
</mtapp:statusmsg>

<ul id="sync-category-from-entry-actions">
    <li>
        <a
            href="<mt:var name='script_url'>?__mode=sync_category_from_entry_edit&amp;blog_id=<mt:var name='blog_id'>"
            class="icon-left icon-action"
        >
            <__trans phrase="Synchronization settings">
        </a>
        <a
            href="javascript:void(0)"
            id="sync-category-from-entry-resync"
            class="icon-left icon-action"
        >
            <__trans phrase="Resynchronize now">
        </a>
    </li>
</ul>
</__trans_section>
    });

    my @targets = grep {
        $_->getAttribute('name') =~ m!include/header!;
    } @{$tmpl->getElementsByTagName('include')};

    my $target = shift @targets || return 1;
    $tmpl->insertBefore($content_header, $target);

    1;
}

sub edit {
    my $app = shift;
    my %param;
    %param = %{ $_[0] } if $_[0];
    my $q = $app->param;
    my $blog_id = $q->param('blog_id');
    return $app->return_to_dashboard( redirect => 1 ) unless $blog_id;

    my $perms = $app->permissions;
    return $app->permission_denied
        unless $app->can_do('edit_categories');

    my $blog = $app->model('blog')->load($blog_id)
        or return $app->error(plugin->translate('Cannot load blog #{_1].', $blog_id));

    return $app->return_to_dashboard( redirect => 1 ) unless $blog->is_blog;

    my $sync_from = $param{sync_from};
    $sync_from = $blog->category_sync_entry_from || 0
        unless defined $sync_from;

    # Gather blogs
    my @blogs = (
        {
            id => 0,
            name => plugin->translate('No synchronization'),
            active => ($sync_from == 0 ? 1 : 0),
        }
    );

    if ( my $site_iter = MT->model('website')->load_iter({}, { sort => 'name' }) ) {
        while ( my $s = $site_iter->() ) {
            for my $b ( @{$s->blogs} ) {
                next if $b->id == $blog->id;
                push @blogs, {
                    id => $b->id,
                    name => plugin->translate('[_1] &raquo; [_2]', $s->name, $b->name),
                    active => ($sync_from == $b->id ? 1 : 0),
                };
            }
        }
    }

    my $update = $blog->category_sync_entry_force_update;
    $update = 1 unless defined $update;
    my $remove = $blog->category_sync_entry_force_remove;
    $remove = 1 unless defined $remove;

    %param = (
        saved => $q->param('saved') || 0,
        unsync => $q->param('unsync') || 0,
        synchronized => $q->param('synchronized') || 0,
        sync_from => $sync_from,
        update => $update,
        remove => $remove,
        %param,
        blog_id => $blog_id,
        blogs => \@blogs,
    );

    return plugin->load_tmpl('cfg_sync_category_from_entry.tmpl', \%param);
}

sub save {
    my $app = shift;
    my %param;
    my $q = $app->param;
    my $blog_id = $q->param('blog_id');
    return $app->return_to_dashboard( redirect => 1 ) unless $blog_id;

    my $perms = $app->permissions;
    return $app->permission_denied
        unless $app->can_do('edit_categories');

    my $blog = $app->model('blog')->load($blog_id)
        or return $app->error(plugin->translate('Cannot load blog #[_1].', $blog_id));

    return $app->return_to_dashboard( redirect => 1 ) unless $blog->is_blog;

    # Save
    my $sync_from = $q->param('sync_from') || 0;
    if ( $sync_from ) {
        if ( my $b = MT->model('blog')->load({ id => $sync_from, class => 'blog'}) ) {
            $blog->category_sync_entry_from($sync_from);
            $blog->category_sync_entry_force_update($q->param('update') ? 1: 0);
            $blog->category_sync_entry_force_remove($q->param('remove') ? 1: 0);
            $blog->save;

            my $synchronized = 0;
            if ( $q->param('sync_now') ) {
                local $@;
                eval {
                    resync_blog($blog, $app->user);
                };
                if ( $@ ) {
                    $param{error} = $@;
                    return edit($app, \%param);
                }
                $synchronized = 1;
            }

            return $app->redirect(
                $app->uri( mode => 'sync_category_from_entry_edit', args => {
                    blog_id => $blog_id,
                    saved => 1,
                    synchronized => $synchronized,
                } )
            );
        } else {
            $param{error} = plugin->translate('Cannot load blog #[_1]', $sync_from);
        }
    } else {
        $blog->category_sync_entry_from($sync_from);
        $blog->category_sync_entry_force_update($q->param('update') ? 1: 0);
        $blog->category_sync_entry_force_remove($q->param('remove') ? 1: 0);
        $blog->save;

        return $app->redirect(
            $app->uri( mode => 'sync_category_from_entry_edit', args => {
                blog_id => $blog_id,
                unsync => 1,
            } )
        );
    }

    return edit($app, \%param);
}

1;
__END__
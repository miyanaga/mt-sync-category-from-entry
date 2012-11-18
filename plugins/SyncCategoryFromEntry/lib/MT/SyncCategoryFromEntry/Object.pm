use strict;

package MT::SyncCategoryFromEntry::Object;

use warnings;

package MT::Blog;

sub resync {
	my $self = shift;
	my $blog_id = $self->category_sync_entry_from || return;

	
}

1;
__END__
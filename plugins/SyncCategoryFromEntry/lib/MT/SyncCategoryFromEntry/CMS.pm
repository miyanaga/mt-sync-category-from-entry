package MT::SyncCategoryFromEntry::CMS;

use strict;
use warnings;

use MT::SyncCategoryFromEntry::Util;

sub on_template_param_cfg_entry {
	my ( $cb, $app, $tmpl, $param ) = @_;

	my $insertion = plugin->load_tmpl('cfg_sync_category_from_entry') || return;
	my $target = $tmpl->getElementById('display-settings');
	$tmpl->insertAfter($insertion, $target);

	1;
}

1;
__END__
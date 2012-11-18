package MT::SyncCategoryFromEntry::L10N::ja;

use strict;
use utf8;
use base 'MT::SyncCategoryFromEntry::L10N::en_us';
use vars qw( %Lexicon );

%Lexicon = (
    'You used an \'[_1]\' tag outside of the context of a category' => '[_1]をカテゴリのコンテキスト外で利用しようとしています。',
    'You used an \'[_1]\' tag outside of the context of an entry; Perhaps you mistakenly placed it outside of an \'MTEntries\' container tag?' => '[_1]をコンテキスト外で利用しようとしています。MTEntriesコンテナタグの外部で使っていませんか?',
);

1;

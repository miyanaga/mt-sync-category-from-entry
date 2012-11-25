package MT::SyncCategoryFromEntry::L10N::ja;

use strict;
use utf8;
use base 'MT::SyncCategoryFromEntry::L10N::en_us';
use vars qw( %Lexicon );

%Lexicon = (
    'You used an \'[_1]\' tag outside of the context of a category' => '[_1]をカテゴリのコンテキスト外で利用しようとしています。',
    'You used an \'[_1]\' tag outside of the context of an entry; Perhaps you mistakenly placed it outside of an \'MTEntries\' container tag?' => '[_1]をコンテキスト外で利用しようとしています。MTEntriesコンテナタグの外部で使っていませんか?',

    'Categories in this blog will be synchronized from entries in "[_1]"'
        => 'このブログのカテゴリを[_1]のブログ記事と同期されています。',

    'Category Synchronization' => 'カテゴリ同期',
    'Synchronization settings' => '同期設定',
    'Category Synchronization Setting' => 'カテゴリ同期設定',
    'Resynchronize now' => '今すぐ再同期',
    'No synchronization' => '同期しない',
    'Synchronize categories with entries in another blog.' => '他のブログのブログ記事とカテゴリを同期させます。',

    'No Title' => 'タイトルなし',

    'Category synchronization settings have been saved.' => 'カテゴリ同期設定を保存しました',
    'Category synchronization have been stoped.' => 'カテゴリ同期を終了しました',
    'Categories have been synchronized from entries.' => 'カテゴリがブログ記事から同期されました',

    'Synchronize categories in this blog from entries in the another blog.' => 'このブログのカテゴリを他のブログのブログ記事から同期させます',

    'Update categories even if changed after sync' => '同期後に変更されたカテゴリも同期により更新する',
    'Remove categories not in entries sync from' => '同期元のブログ記事が削除されたらカテゴリも削除する',

);

1;

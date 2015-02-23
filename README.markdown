# sleuth.vim

This plugin automatically adjusts `'shiftwidth'` and `'expandtab'`
heuristically based on the current file, or, in the case the current file is
new, blank, or otherwise insufficient, by looking at other files of the same
type in the current and parent directories.  In lieu of adjusting
`'softtabstop'`, `'smarttab'` is enabled.

Compare to [DetectIndent][].  I wrote this because I wanted something fully
automatic.  My goal is that by installing this plugin, you can remove all
indenting related configuration from your vimrc.

[DetectIndent]: http://www.vim.org/scripts/script.php?script_id=1171

## Installation

If you don't have a preferred installation method, I recommend
installing [pathogen.vim](https://github.com/tpope/vim-pathogen), and
then simply copy and paste:

    cd ~/.vim/bundle
    git clone git://github.com/tpope/vim-sleuth.git

## Notes

* Searching for other files of the same type continues up the directory
  hierarchy until a match is found. This means, for example, the indent for
  the first file in a brand new Ruby project might very well be derived from
  your `.irbrc`.  I consider this a feature.
* If your file is consistently indented with hard tabs, `'shiftwidth'` will be
  set to your `'tabstop'`.  Otherwise, a `'tabstop'` of 8 is enforced.
* The algorithm is rolled from scratch, fairly simplistic, and only lightly
  battle tested.  It's probably not (yet) as good as [DetectIndent][].
  Let me know what it fails on for you.

## Self-Promotion

Like sleuth.vim?  Follow the repository on
[GitHub](https://github.com/tpope/vim-sleuth) and vote for it on
[vim.org](http://www.vim.org/scripts/script.php?script_id=4375).  And if
you're feeling especially charitable, follow [tpope](http://tpo.pe/) on
[Twitter](http://twitter.com/tpope) and
[GitHub](https://github.com/tpope).

## License

Copyright © Tim Pope.  Distributed under the same terms as Vim itself.
See `:help license`.

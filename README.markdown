# sleuth.vim

This plugin automatically adjusts `'shiftwidth'` and `'expandtab'`
heuristically based on the current file, or, in the case the current file is
new, blank, or otherwise insufficient, by looking at other files of the same
type in the current and parent directories.  Modelines and [EditorConfig][]
are also consulted, adding `'tabstop'`, `'textwidth'`, `'endofline'`,
`'fileformat'`, `'fileencoding'`, and `'bomb'` to the list of supported
options.

Compare to [DetectIndent][].  I wrote this because I wanted something fully
automatic.  My goal is that by installing this plugin, you can remove all
indenting related configuration from your vimrc.

[EditorConfig]: https://editorconfig.org/
[DetectIndent]: http://www.vim.org/scripts/script.php?script_id=1171

## Installation

Install using your favorite package manager, or use Vim's built-in package
support:

    mkdir -p ~/.vim/pack/tpope/start
    cd ~/.vim/pack/tpope/start
    git clone https://tpope.io/vim/sleuth.git
    vim -u NONE -c "helptags sleuth/doc" -c q

## Notes

* If your file is consistently indented with hard tabs, `'shiftwidth'` will be
  set to your `'tabstop'`.  Otherwise, a `'tabstop'` of 8 is enforced, unless
  another value is explicitly declared in a modeline or EditorConfig.

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

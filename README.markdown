# sleuth.vim

This plugin adapt vim indentation to the current or neighbouring files. it will detect if spaces are used as indentation and the number of spaces.

It only changes expandtab and shiftwidth away from default values. tabstop and all other settings are left intact.

 disable neighbour scanning with

    :set b:sleuth_neighbor_lim=0

## Installation

Install using your favorite package manager, or use Vim's built-in package
support:

    mkdir -p ~/.vim/pack/abc/start
    cd ~/.vim/pack/abc/start
    git clone --depth=1 https://github.com/tpope/vim-sleuth
    vim -u NONE -c "helptags sleuth/doc" -c q

If you need to modify the plugin test the changes in the same vim session with 

    :unlet g:loaded_sleuth | w | Sleuth

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

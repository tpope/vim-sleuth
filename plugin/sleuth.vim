" sleuth.vim - Heuristically set buffer options
" Maintainer:   Tim Pope <http://tpo.pe/>
" Version:      1.2
" GetLatestVimScripts: 4375 1 :AutoInstall: sleuth.vim

if exists("g:loaded_sleuth") || v:version < 700 || &cp
  finish
endif
let g:loaded_sleuth = 1

function! s:Guess(lines, source) abort
  let options = {}
  let heuristics = {'spaces': 0, 'hard': 0, 'soft': 0, 'three': 0}
  let softtab = repeat(' ', 8)
  let waiting_on = ''

  for line in a:lines
    if len(waiting_on)
      if line =~# waiting_on
        let waiting_on = ''
      endif
      continue
    elseif line =~# '^\s*$'
      continue
    elseif line =~# '^\s*/\*' && line !~# '\*/'
      let waiting_on = '\*/'
    elseif line =~# '^\s*<\!--' && line !~# '-->'
      let waiting_on = '-->'
    elseif line =~# '^[^"]*"""[^"]*$'
      let waiting_on = '^[^"]*"""[^"]*$'
    elseif line =~# '^=\w' && line !~# '^=\%(end\|cut\)\>'
      let waiting_on = '^=\%(end\|cut\)\>'
    elseif line =~# '^@@\+ -\d\+,\d\+ '
      let waiting_on = '^$'
    elseif &filetype ==# 'go' && line =~# '^[^`]*`[^`]*$'
      let waiting_on = '^[^`]*`[^`]*$'
    elseif &filetype =~# '^\%(perl\|php\|ruby\|[cz]\=sh\)$'
      let waiting_on = matchstr(line, '<<\s*\([''"]\=\)\zs\w\+\ze\1[^''"`<>]*$')
      if len(waiting_on)
        let waiting_on = '^' . waiting_on . '$'
      endif
    endif

    if line =~# '^\t'
      let heuristics.hard += 1
    elseif line =~# '^' . softtab
      let heuristics.soft += 1
    endif
    if line =~# '^  '
      let heuristics.spaces += 1
    endif
    let indent = len(matchstr(substitute(line, '\t', softtab, 'g'), '^ *'))
    if indent == 3
      let heuristics.three += 1
    elseif indent > 1 && (indent < 4 || indent % 4 == 0) &&
          \ get(options, 'shiftwidth', 99) > indent
      let options.shiftwidth = indent
    endif
  endfor

  if heuristics.three && get(options, 'shiftwidth', '') !~# '^[248]$'
    let options.shiftwidth = 3
  endif
  if heuristics.hard && !heuristics.spaces
    let options = {'expandtab': 0, 'shiftwidth': 0}
  elseif heuristics.soft != heuristics.hard
    let options.expandtab = heuristics.soft > heuristics.hard
    if heuristics.hard || stridx(join(a:lines, "\n"), "\t") >= 0
      let options.tabstop = 8
    endif
  endif

  return map(options, '[v:val, a:source]')
endfunction

function! s:Capture(cmd) abort
  redir => capture
  silent execute a:cmd
  redir END
  return capture
endfunction

function! s:PatternsFor(type) abort
  if a:type ==# ''
    return []
  endif
  if !exists('s:patterns')
    let capture = s:Capture('autocmd BufRead')
    let patterns = {
          \ 'c': ['*.c', '*.h'],
          \ 'cpp': ['*.cpp', '*.h'],
          \ 'html': ['*.html'],
          \ 'sh': ['*.sh'],
          \ 'vim': ['vimrc', '.vimrc', '_vimrc'],
          \ }
    let setfpattern = '\s\+\%(setf\%[iletype]\s\+\|set\%[local]\s\+\%(ft\|filetype\)=\|call SetFileTypeSH(["'']\%(ba\|k\)\=\%(sh\)\@=\)'
    for line in split(capture, "\n")
      let match = matchlist(line, '^\s*\(\S\+\)\='.setfpattern.'\(\w\+\)')
      if !empty(match)
        call extend(patterns, {match[2]: []}, 'keep')
        call extend(patterns[match[2]], [match[1] ==# '' ? last : match[1]])
      endif
      let last = matchstr(line, '\S.*')
    endfor
    let patterns.markdown = []
    call map(patterns, 'sort(v:val)')
    let s:patterns = patterns
  endif
  return copy(get(s:patterns, a:type, []))
endfunction

let s:modeline_numbers = {
      \ 'shiftwidth': 'shiftwidth', 'sw': 'shiftwidth',
      \ 'tabstop': 'tabstop', 'ts': 'tabstop',
      \ }
let s:modeline_booleans = {
      \ 'expandtab': 'expandtab', 'et': 'expandtab',
      \ }
function! s:ModelineOptions(source) abort
  let options = {}
  if !&l:modeline && (&g:modeline || s:Capture('setlocal') =~# '\\\@<![[:space:]]nomodeline\>')
    return options
  endif
  let modelines = get(b:, 'sleuth_modelines', get(g:, 'sleuth_modelines', 5))
  if line('$') > 2 * modelines
    let lnums = range(1, modelines) + range(line('$') - modelines + 1, line('$'))
  else
    let lnums = range(1, line('$'))
  endif
  for lnum in lnums
    for option in split(matchstr(getline(lnum), '\%(\S\@<!vim\=\|\s\@<=ex\):\s*\(set\= \zs[^:]\+\|\zs.*\S\)'), '[[:space:]:]\+')
      if has_key(s:modeline_booleans, matchstr(option, '^\%(no\)\=\zs\w\+$'))
        let options[s:modeline_booleans[matchstr(option, '^\%(no\)\=\zs\w\+')]] = [option !~# '^no', a:source, lnum]
      elseif has_key(s:modeline_numbers, matchstr(option, '^\w\+\ze=[1-9]\d*$'))
        let options[s:modeline_numbers[matchstr(option, '^\w\+')]] = [str2nr(matchstr(option, '\d\+$')), a:source, lnum]
      elseif option ==# 'nomodeline' || option ==# 'noml'
        return options
      endif
    endfor
  endfor
  return options
endfunction

function! s:Ready(options) abort
  return has_key(a:options, 'expandtab') && has_key(a:options, 'shiftwidth')
endfunction

function! s:Apply(detected) abort
  let options = copy(a:detected.options)
  if !exists('*shiftwidth') && !get(options, 'shiftwidth', [1])[0]
    let options.shiftwidth = get(options, 'tabstop', [&tabstop])[0] + options.shiftwidth[1:-1]
  endif
  let msg = ''
  for option in sort(keys(options))
    if exists('&' . option)
      let value = options[option]
      call setbufvar('', '&'.option, value[0])
      if has_key(s:modeline_booleans, option)
        let setting = (value[0] ? '' : 'no') . option
      else
        let setting = option . '=' . value[0]
      endif
      if !&verbose
        let msg .= ' ' . setting
        continue
      endif
      if len(value) > 1
        let file = value[1] ==# a:detected.bufname ? '%' : fnamemodify(value[1], ':~:.')
        if len(value) > 2
          let file .= ' line ' . value[2]
        endif
        echo printf(':setlocal %-13s " from %s', setting, file)
      else
        echo ':setlocal ' . setting
      endif
    endif
  endfor
  if !&verbose && !empty(msg)
    echo ':setlocal' . msg
  endif
  if !s:Ready(options)
    echohl WarningMsg
    echo ':Sleuth failed to detect indent settings'
    echohl NONE
  endif
endfunction

let s:mandated = {
      \ 'yaml': {'expandtab': [1]},
      \ }

function! s:Detect() abort
  let file = tr(expand('%:p'), exists('+shellslash') ? '\' : '/', '/')
  let options = {}
  let detected = {'bufname': file, 'options': options}

  let declared = copy(get(s:mandated, &filetype, {}))
  call extend(declared, s:ModelineOptions(file))
  call extend(options, declared)
  if s:Ready(options)
    return detected
  endif

  let lines = getline(1, 1024)
  call extend(options, s:Guess(lines, file), 'keep')
  if s:Ready(options)
    return detected
  endif
  let dir = fnamemodify(file, ':h')
  if dir =~# '^\a\a\+:' || !isdirectory(dir)
    let dir = ''
  endif
  let c = get(b:, 'sleuth_neighbor_limit', get(g:, 'sleuth_neighbor_limit', 8))
  let patterns = c > 0 && len(dir) ? s:PatternsFor(&filetype) : []
  call filter(patterns, 'v:val !~# "/"')
  while c > 0 && dir !~# '^$\|^//[^/]*$' && dir !=# fnamemodify(dir, ':h')
    let last_pattern = ''
    for pattern in patterns
      if pattern ==# last_pattern
        continue
      endif
      let last_pattern = pattern
      for neighbor in split(glob(dir.'/'.pattern), "\n")[0:7]
        if neighbor !=# expand('%:p') && filereadable(neighbor)
          call extend(options, s:Guess(readfile(neighbor, '', 256), neighbor), 'keep')
          let c -= 1
        endif
        if s:Ready(options)
          return detected
        endif
        if c <= 0
          break
        endif
      endfor
      if c <= 0
        break
      endif
    endfor
    let dir = fnamemodify(dir, ':h')
  endwhile
  if has_key(options, 'shiftwidth')
    let options.expandtab = [1]
  else
    let detected.options = declared
  endif
  return detected
endfunction

function! s:Sleuth() abort
  if &buftype ==# 'help'
    echohl WarningMsg
    echo ':Sleuth disabled for buftype=' . &buftype
    echohl NONE
    return
  endif
  let detected = s:Detect()
  call s:Apply(detected)
endfunction

setglobal smarttab

if !exists('g:did_indent_on')
  filetype indent on
endif

function! SleuthIndicator() abort
  let sw = &shiftwidth ? &shiftwidth : &tabstop
  if &expandtab
    return 'sw='.sw
  elseif &tabstop == sw
    return 'ts='.&tabstop
  else
    return 'sw='.sw.',ts='.&tabstop
  endif
endfunction

augroup sleuth
  autocmd!
  autocmd FileType *
        \ if get(b:, 'sleuth_automatic', get(g:, 'sleuth_automatic', 1))
        \ | silent call s:Sleuth() | endif
  autocmd User Flags call Hoist('buffer', 5, 'SleuthIndicator')
augroup END

command! -bar -bang Sleuth call s:Sleuth()

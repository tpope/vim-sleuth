" sleuth.vim - Heuristically set buffer options
" Maintainer:   Tim Pope <http://tpo.pe/>
" Version:      1.2
" GetLatestVimScripts: 4375 1 :AutoInstall: sleuth.vim

if exists("g:loaded_sleuth") || v:version < 700 || &cp
  finish
endif
let g:loaded_sleuth = 1

if exists('+shellslash')
  function! s:Slash(path) abort
    return tr(a:path, '\', '/')
  endfunction
else
  function! s:Slash(path) abort
    return a:path
  endfunction
endif

function! s:Guess(source, detected, lines) abort
  let has_heredocs = &filetype =~# '^\%(perl\|php\|ruby\|[cz]\=sh\)$'
  let options = {}
  let heuristics = {'spaces': 0, 'hard': 0, 'soft': 0, 'checked': 0, 'indents': {}}
  let tabstop = get(a:detected.options, 'tabstop', [8])[0]
  let softtab = repeat(' ', tabstop)
  let waiting_on = ''
  let prev_indent = -1

  for line in a:lines
    if len(waiting_on)
      if line =~# waiting_on
        let waiting_on = ''
        let prev_indent = -1
      endif
      continue
    elseif line =~# '^\s*$'
      continue
    elseif line =~# '^=\w' && line !~# '^=\%(end\|cut\)\>'
      let waiting_on = '^=\%(end\|cut\)\>'
    elseif line =~# '^@@\+ -\d\+,\d\+ '
      let waiting_on = '^$'
    elseif line !~# '[/<"`]'
      " No need to do other checks
    elseif line =~# '^\s*/\*' && line !~# '\*/'
      let waiting_on = '\*/'
    elseif line =~# '^\s*<\!--' && line !~# '-->'
      let waiting_on = '-->'
    elseif line =~# '^[^"]*"""[^"]*$'
      let waiting_on = '^[^"]*"""[^"]*$'
    elseif &filetype ==# 'go' && line =~# '^[^`]*`[^`]*$'
      let waiting_on = '^[^`]*`[^`]*$'
    elseif has_heredocs
      let waiting_on = matchstr(line, '<<\s*\([''"]\=\)\zs\w\+\ze\1[^''"`<>]*$')
      if len(waiting_on)
        let waiting_on = '^' . waiting_on . '$'
      endif
    endif

    let indent = len(matchstr(substitute(line, '\t', softtab, 'g'), '^ *'))
    if line =~# '^\t'
      let heuristics.hard += 1
    elseif line =~# '^' . softtab
      let heuristics.soft += 1
    endif
    if line =~# '^  '
      let heuristics.spaces += 1
    endif
    let increment = prev_indent < 0 ? 0 : indent - prev_indent
    let prev_indent = indent
    if increment > 1 && (increment < 4 || increment % 4 == 0)
      if has_key(heuristics.indents, increment)
        let heuristics.indents[increment] += 1
      else
        let heuristics.indents[increment] = 1
      endif
      let heuristics.checked += 1
    endif
    if heuristics.checked >= 32 && (heuristics.hard > 3 || heuristics.soft > 3) && get(heuristics.indents, increment) * 2 > heuristics.checked
      if heuristics.spaces
        break
      elseif !exists('no_space_indent')
        let no_space_indent = stridx("\n" . join(a:lines, "\n"), "\n  ") < 0
        if no_space_indent
          break
        endif
      endif
      break
    endif
  endfor

  let max_frequency = 0
  for [shiftwidth, frequency] in items(heuristics.indents)
    if frequency > max_frequency
      let options.shiftwidth = +shiftwidth
      let max_frequency = frequency
    endif
  endfor

  if heuristics.hard && !heuristics.spaces &&
        \ !has_key(a:detected.options, 'tabstop')
    let options = {'expandtab': 0, 'shiftwidth': 0}
  elseif heuristics.hard > heuristics.soft
    let options.expandtab = 0
    let options.tabstop = tabstop
  else
    if heuristics.soft
      let options.expandtab = 1
    endif
    if heuristics.hard || has_key(a:detected.options, 'tabstop') ||
          \ stridx(join(a:lines, "\n"), "\t") >= 0
      let options.tabstop = tabstop
    elseif !&g:shiftwidth && has_key(options, 'shiftwidth')
      let options.tabstop = options.shiftwidth
      let options.shiftwidth = 0
    endif
  endif

  call map(options, '[v:val, a:source]')
  call extend(a:detected.options, options, 'keep')
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
      \ 'textwidth': 'textwidth', 'tw': 'textwidth',
      \ }
let s:modeline_booleans = {
      \ 'expandtab': 'expandtab', 'et': 'expandtab',
      \ 'fixendofline': 'fixendofline', 'fixeol': 'fixendofline',
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

let s:fnmatch_replacements = {
      \ '.': '\.', '\%': '%', '\(': '(', '\)': ')', '\{': '{', '\}': '}', '\_': '_',
      \ '?': '[^/]', '*': '[^/]*', '/**/*': '/.*', '/**/': '/\%(.*/\)\=', '**': '.*'}
function! s:FnmatchReplace(pat) abort
  if has_key(s:fnmatch_replacements, a:pat)
    return s:fnmatch_replacements[a:pat]
  elseif len(a:pat) ==# 1
    return '\' . a:pat
  elseif a:pat =~# '^{[+-]\=\d\+\.\.[+-]\=\d\+}$'
    return '\%(' . join(range(matchstr(a:pat, '[+-]\=\d\+'), matchstr(a:pat, '\.\.\zs[+-]\=\d\+')), '\|') . '\)'
  elseif a:pat =~# '^{.*\\\@<!\%(\\\\\)*,.*}$'
    return '\%(' . substitute(a:pat[1:-2], ',\|\%(\\.\|{[^\{}]*}\|[^,]\)*', '\=submatch(0) ==# "," ? "\\|" : s:FnmatchTranslate(submatch(0))', 'g') . '\)'
  elseif a:pat =~# '^{.*}$'
    return '{' . s:FnmatchTranslate(a:pat[1:-2]) . '}'
  elseif a:pat =~# '^\[!'
    return '[^' . a:pat[2:-1]
  else
    return a:pat
  endif
endfunction

function! s:FnmatchTranslate(pat) abort
  return substitute(a:pat, '\\.\|/\*\*/\*\=\|\*\*\=\|\[[!^]\=\]\=[^]/]*\]\|{\%(\\.\|[^{}]\|{[^\{}]*}\)*}\|[?.\~^$[]', '\=s:FnmatchReplace(submatch(0))', 'g')
endfunction

function! s:ReadEditorConfig(absolute_path) abort
  try
    let lines = readfile(a:absolute_path)
  catch
    let lines = []
  endtry
  let prefix = '\m\C^' . escape(fnamemodify(a:absolute_path, ':h'), '][^$.*\~')
  let preamble = {}
  let pairs = preamble
  let sections = []
  let i = 0
  while i < len(lines)
    let line = lines[i]
    let i += 1
    let line = substitute(line, '^[[:space:]]*\|[[:space:]]*\%([^[:space:]]\@<![;#].*\)\=$', '', 'g')
    let match = matchlist(line, '^\%(\[\(\%(\\.\|[^\;#]\)*\)\]\|\([^[:space:]]\@=[^;#=:]*[^;#=:[:space:]]\)[[:space:]]*[=:][[:space:]]*\(.*\)\)$')
    if len(get(match, 2, ''))
      let pairs[tolower(match[2])] = [match[3], a:absolute_path, i]
    elseif len(get(match, 1, '')) && len(get(match, 1, '')) <= 4096
      if match[1] =~# '^/'
        let pattern = match[1]
      elseif match[1] =~# '/'
        let pattern = '/' . match[1]
      else
        let pattern = '/**/' . match[1]
      endif
      let pairs = {}
      call add(sections, [prefix . s:FnmatchTranslate(pattern) . '$', pairs])
    endif
  endwhile
  return [preamble, sections]
endfunction

let s:editorconfig_cache = {}
function! s:DetectEditorConfig(absolute_path, ...) abort
  let root = ''
  let tail = a:0 ? '/' . a:1 : '/.editorconfig'
  let dir = fnamemodify(a:absolute_path, ':h')
  let previous_dir = ''
  let sections = []
  while dir !=# previous_dir && dir !~# '^//\%([^/]\+/\=\)\=$'
    let read_from = dir . tail
    let ftime = getftime(read_from)
    let [cachetime; config] = get(s:editorconfig_cache, read_from, [-1, {}, []])
    if ftime != cachetime
      let config = s:ReadEditorConfig(read_from)
      let s:editorconfig_cache[read_from] = [ftime] + config
      lockvar! s:editorconfig_cache[read_from]
      unlockvar s:editorconfig_cache[read_from]
    endif
    call extend(sections, config[1], 'keep')
    if get(config[0], 'root', [''])[0] ==? 'true'
      let root = dir
      break
    endif
    let previous_dir = dir
    let dir = fnamemodify(dir, ':h')
  endwhile

  let config = {}
  for [pattern, pairs] in sections
    if a:absolute_path =~# pattern
      call extend(config, pairs)
    endif
  endfor

  return [config, root]
endfunction

function! s:EditorConfigToOptions(pairs) abort
  let options = {}
  let pairs = map(copy(a:pairs), 'v:val[0]')
  let sources = map(copy(a:pairs), 'v:val[1:-1]')
  call filter(pairs, 'v:val !=? "unset"')

  if get(pairs, 'indent_style', '') ==? 'tab'
    let options.expandtab = [0] + sources.indent_style
  elseif get(pairs, 'indent_style', '') ==? 'space'
    let options.expandtab = [1] + sources.indent_style
  endif

  if get(pairs, 'indent_size', '') =~? '^[1-9]\d*$\|^tab$'
    let options.shiftwidth = [str2nr(pairs.indent_size)] + sources.indent_size
    if &g:shiftwidth == 0 && !has_key(pairs, 'tab_width') && pairs.indent_size !=? 'tab'
      let options.tabstop = options.shiftwidth
      let options.shiftwidth = [0] + sources.indent_size
    endif
  endif

  if get(pairs, 'tab_width', '') =~? '^[1-9]\d*$'
    let options.tabstop = [str2nr(pairs.tab_width)] + sources.tab_width
    if !has_key(pairs, 'indent_size') && get(pairs, 'indent_style', '') ==? 'tab'
      let options.shiftwidth = [0] + options.tabstop[1:-1]
    endif
  endif

  if get(pairs, 'max_line_length', '') =~? '^[1-9]\d*$\|^off$'
    let options.textwidth = [str2nr(pairs.max_line_length)] + sources.max_line_length
  endif

  if get(pairs, 'insert_final_newline', '') =~? '^true$\|^false$'
    let options.fixendofline = [pairs.insert_final_newline ==? 'true'] + sources.insert_final_newline
  endif

  return options
endfunction

function! s:Ready(detected) abort
  return has_key(a:detected.options, 'expandtab') && has_key(a:detected.options, 'shiftwidth')
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
  if !s:Ready(a:detected)
    echohl WarningMsg
    echo ':Sleuth failed to detect indent settings'
    echohl NONE
  endif
endfunction

let s:mandated = {
      \ 'yaml': {'expandtab': [1]},
      \ }

function! s:Detect() abort
  let file = s:Slash(@%)
  if len(&l:buftype)
    let file = s:Slash(fnamemodify(file, ':p'))
  elseif file !~# '^$\|^\a\+:\|^/'
    let file = s:Slash(getcwd()) . '/' . file
  endif
  let options = {}
  let detected = {'bufname': file, 'options': options}
  let pre = substitute(matchstr(file, '^\a\a\+\ze:'), '^\a', '\u&', 'g')
  if len(pre) && exists('*' . pre . 'Real')
    let file = s:Slash(call(pre . 'Real', [file]))
  endif

  let declared = copy(get(s:mandated, &filetype, {}))
  let [detected.editorconfig, detected.root] = s:DetectEditorConfig(file)
  call extend(declared, s:EditorConfigToOptions(detected.editorconfig))
  call extend(declared, s:ModelineOptions(file))
  call extend(options, declared)
  if s:Ready(detected)
    return detected
  endif

  let lines = getline(1, 1024)
  call s:Guess(detected.bufname, detected, lines)
  if s:Ready(detected)
    return detected
  endif
  let dir = fnamemodify(file, ':h')
  let root = len(detected.root) ? detected.root : dir ==# s:Slash(expand('~')) ? dir : fnamemodify(dir, ':h')
  if detected.bufname =~# '^\a\a\+:' || !isdirectory(root)
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
        if neighbor !=# file && filereadable(neighbor)
          call s:Guess(neighbor, detected, readfile(neighbor, '', 256))
          let c -= 1
        endif
        if s:Ready(detected)
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
    if len(dir) <= len(root)
      break
    endif
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
  if &l:buftype =~# '^\%(help\|terminal\)$'
    echohl WarningMsg
    echo ':Sleuth disabled for buftype=' . &l:buftype
    echohl NONE
    return
  endif
  if &l:filetype ==# 'netrw'
    echohl WarningMsg
    echo ':Sleuth disabled for filetype=' . &l:filetype
    echohl NONE
    return
  endif
  let detected = s:Detect()
  call s:Apply(detected)
endfunction

setglobal smarttab

if !exists('g:did_indent_on') && !get(g:, 'sleuth_no_filetype_indent_on')
  filetype indent on
elseif !exists('g:did_load_filetypes')
  filetype on
endif

function! SleuthIndicator() abort
  let sw = &shiftwidth ? &shiftwidth : &tabstop
  if &expandtab
    let ind = 'sw='.sw
  elseif &tabstop == sw
    let ind = 'ts='.&tabstop
  else
    let ind = 'sw='.sw.',ts='.&tabstop
  endif
  if &textwidth
    let ind .= ',tw='.&textwidth
  endif
  if exists('&fixendofline') && !&fixendofline && !&endofline
    let ind .= ',noeol'
  endif
  return ind
endfunction

augroup sleuth
  autocmd!
  autocmd FileType * nested
        \ if get(b:, 'sleuth_automatic', get(g:, 'sleuth_automatic', 1))
        \ | silent call s:Sleuth() | endif
  autocmd User Flags call Hoist('buffer', 5, 'SleuthIndicator')
augroup END

command! -bar -bang Sleuth call s:Sleuth()

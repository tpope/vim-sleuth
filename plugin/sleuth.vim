" sleuth.vim - Heuristically set buffer options
" Maintainer:   Tim Pope <http://tpo.pe/>
" Version:      1.3
" GetLatestVimScripts: 4375 1 :AutoInstall: sleuth.vim

if exists("#polyglot-sleuth")
  autocmd! polyglot-sleuth
  augroup! polyglot-sleuth
  unlet! g:loaded_sleuth
  let s:polyglot = 1
endif

if exists("g:loaded_sleuth") || v:version < 700 || &cp
  finish
endif
let g:loaded_sleuth = 1
lockvar g:loaded_sleuth

function! s:Warn(msg) abort
  echohl WarningMsg
  echo a:msg
  echohl NONE
endfunction

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
  let ext = matchstr(a:source, '\.\zs[^./]\+$')
  let has_heredocs = ext =~# '^\%(p[lm]\|php\|ruby\|sh\)$' ||
        \ get(a:lines, 0, '') =~# '^#!.*\<\%(perl\|php\|ruby\|[cz]\=sh\|bash\)$\>'
  let is_python = ext ==# 'py' || get(a:lines, 0, '') =~# '^#!.*\<python\d\=\>'
  let options = {}
  let heuristics = {'spaces': 0, 'hard': 0, 'soft': 0, 'checked': 0, 'indents': {}}
  let tabstop = get(a:detected.options, 'tabstop', [8])[0]
  let softtab = repeat(' ', tabstop)
  let waiting_on = ''
  let prev_indent = -1
  let prev_line = ''

  for line in a:lines
    if len(waiting_on)
      if line =~# waiting_on
        let waiting_on = ''
        let prev_indent = -1
        let prev_line = ''
      endif
      continue
    elseif line =~# '^\s*$'
      continue
    elseif is_python && prev_line[1:-1] =~# '[[\({]'
      let prev_indent = -1
      let prev_line = ''
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
    elseif ext ==# 'go' && line =~# '^[^`]*`[^`]*$'
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
    let prev_line = line
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

  let a:detected.heuristics[a:source] = heuristics

  let max_frequency = 0
  for [shiftwidth, frequency] in items(heuristics.indents)
    if frequency > max_frequency || frequency == max_frequency && +shiftwidth < get(options, 'shiftwidth')
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

let s:modeline_numbers = {
      \ 'shiftwidth': 'shiftwidth', 'sw': 'shiftwidth',
      \ 'tabstop': 'tabstop', 'ts': 'tabstop',
      \ 'textwidth': 'textwidth', 'tw': 'textwidth',
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
    let [cachetime; econfig] = get(s:editorconfig_cache, read_from, [-1, {}, []])
    if ftime != cachetime
      let econfig = s:ReadEditorConfig(read_from)
      let s:editorconfig_cache[read_from] = [ftime] + econfig
      lockvar! s:editorconfig_cache[read_from]
      unlockvar s:editorconfig_cache[read_from]
    endif
    call extend(sections, econfig[1], 'keep')
    if get(econfig[0], 'root', [''])[0] ==? 'true'
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

let s:editorconfig_bomb = {
      \ 'utf-8':     0,
      \ 'utf-8-bom': 1,
      \ 'utf-16be':  1,
      \ 'utf-16le':  1,
      \ 'latin1':    0,
      \ }

let s:editorconfig_fileformat = {
      \ 'cr':   'mac',
      \ 'crlf': 'dos',
      \ 'lf':   'unix',
      \ }

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
    let options.endofline = [pairs.insert_final_newline ==? 'true'] + sources.insert_final_newline
  endif

  let eol = tolower(get(pairs, 'end_of_line', ''))
  if has_key(s:editorconfig_fileformat, eol)
    let options.fileformat = [s:editorconfig_fileformat[eol]] + sources.end_of_line
  endif

  let charset = tolower(get(pairs, 'charset', ''))
  if has_key(s:editorconfig_bomb, charset)
    let options.bomb = [s:editorconfig_bomb[charset]] + sources.charset
    let options.fileencoding = [substitute(charset, '\C-bom$', '', '')] + sources.charset
  endif

  return options
endfunction

function! s:Ready(detected) abort
  return has_key(a:detected.options, 'expandtab') && has_key(a:detected.options, 'shiftwidth')
endfunction

let s:booleans = {'expandtab': 1, 'endofline': 1, 'bomb': 1}
let s:safe_options = ['expandtab', 'shiftwidth', 'tabstop', 'textwidth']
let s:all_options = s:safe_options + ['endofline', 'fileformat', 'fileencoding', 'bomb']

function! s:Apply(detected, safe_only) abort
  let options = copy(a:detected.options)
  if !exists('*shiftwidth') && !get(options, 'shiftwidth', [1])[0]
    let options.shiftwidth = get(options, 'tabstop', [&tabstop])[0] + options.shiftwidth[1:-1]
  endif
  let msg = ''
  for option in a:safe_only ? s:safe_options : s:all_options
    if !exists('&' . option) || !has_key(options, option) ||
          \ !&l:modifiable && index(s:safe_options, options) == -1
      continue
    endif
    let value = options[option]
    if has_key(s:booleans, option)
      let setting = (value[0] ? '' : 'no') . option
    else
      let setting = option . '=' . value[0]
    endif
    if getbufvar('', '&' . option) !=# value[0] || index(s:safe_options, option) >= 0
      exe 'setlocal ' . setting
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
      echo printf(':setlocal %-21s " from %s', setting, file)
    else
      echo ':setlocal ' . setting
    endif
  endfor
  if !&verbose && !empty(msg)
    echo ':setlocal' . msg
  endif
  if !s:Ready(a:detected)
    call s:Warn(':Sleuth failed to detect indent settings')
  endif
endfunction

function! s:Detect() abort
  let file = s:Slash(@%)
  let actual_path = !empty(file) && &l:buftype =~# '^\%(nowrite\|acwrite\)\=$'
  if actual_path && file !~# '^$\|^\a\+:\|^/'
    let file = s:Slash(getcwd()) . '/' . file
  endif
  let options = {}
  let detected = {'bufname': file, 'options': options, 'heuristics': {}}
  let pre = substitute(matchstr(file, '^\a\a\+\ze:'), '^\a', '\u&', 'g')
  if len(pre) && exists('*' . pre . 'Real')
    let file = s:Slash(call(pre . 'Real', [file]))
  endif

  let declared = {}
  let detected.declared = declared
  let [detected.editorconfig, detected.root] = actual_path ? s:DetectEditorConfig(file) : [{}, '']
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
  elseif get(options, 'shiftwidth', [4])[0] < 4 && stridx(join(lines, "\n"), "\t") == -1
    let options.expandtab = [1, detected.bufname]
    return detected
  endif
  let dir = actual_path ? fnamemodify(file, ':h') : ''
  let root = len(detected.root) ? detected.root : dir ==# s:Slash(expand('~')) ? dir : fnamemodify(dir, ':h')
  if detected.bufname =~# '^\a\a\+:' || root ==# '.' || !isdirectory(root)
    let dir = ''
  endif
  let c = get(b:, 'sleuth_neighbor_limit', get(g:, 'sleuth_neighbor_limit', 8))
  if c <= 0 || empty(dir)
    let detected.patterns = []
  else
    let detected.patterns = ['*' . matchstr(file, '/\@<!\.[^./]\+$')]
    if detected.patterns ==# ['*']
      let detected.patterns = [matchstr(file, '[^/]\+\ze/\=$')]
      let dir = fnamemodify(dir, ':h')
    endif
  endif
  while c > 0 && dir !~# '^$\|^//[^/]*$' && dir !=# fnamemodify(dir, ':h')
    for pattern in detected.patterns
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
    let options.expandtab = [stridx(join(lines, "\n"), "\t") == -1, detected.bufname]
  else
    let detected.options = declared
  endif
  return detected
endfunction

function! s:Init(safe_only) abort
  if &l:buftype =~# '^\%(quickfix\|help\|terminal\|prompt\|popup\)$'
    return s:Warn(':Sleuth disabled for buftype=' . &l:buftype)
  endif
  if &l:filetype ==# 'netrw'
    return s:Warn(':Sleuth disabled for filetype=' . &l:filetype)
  endif
  let b:sleuth = s:Detect()
  call s:Apply(b:sleuth, a:safe_only)
  if exists('s:polyglot')
    call s:Warn('Charlatan :Sleuth implementation in vim-polyglot has been found and disabled.')
    call s:Warn('To get rid of this message, uninstall vim-polyglot, or disable the')
    call s:Warn('corresponding feature in your vimrc:')
    call s:Warn('        let g:polyglot_disabled = ["autoindent"]')
  endif
endfunction

function! s:Sleuth(line1, line2, range, bang, mods, args) abort
  call s:Init(a:bang)
  return ''
endfunction

setglobal smarttab
if exists('&fixendofline')
  setglobal nofixendofline
endif

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
  autocmd BufNewFile,BufReadPost,BufFilePost * nested
        \ if get(b:, 'sleuth_automatic', get(g:, 'sleuth_automatic', 1))
        \ | silent call s:Init(0) | endif
  autocmd FileType * nested
        \ if exists('b:sleuth') | silent call s:Apply(b:sleuth, 1) | endif
  autocmd User Flags call Hoist('buffer', 5, 'SleuthIndicator')
augroup END

command! -bar -bang Sleuth exe s:Sleuth(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)

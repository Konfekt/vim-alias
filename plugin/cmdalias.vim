" FORK by EPN of Hari Krishna Dara's cmdalias.vim 3.0.0 that
"   - allows for aliases with non-alphabetic characters, and
"   - allows for aliases of commands that can be preceded by ranges,
"   - adds a documentation, and
"   - does some additional sanity checks.

if exists('g:loaded_cmdalias')
  finish
endif
if v:version < 700
  echomsg 'cmdalias: You need Vim 7.0 or higher'
  finish
endif
let g:loaded_cmdalias = 301

" Make sure line-continuations won't cause any problem. This will be restored
"   at the end
let s:save_cpo = &cpo
set cpo&vim

if !exists('g:cmdaliasCmdPrefixes')
  let g:cmdaliasCmdPrefixes = [
        \ '\d*verb\%[ose]', 'debug', 'sil\%[ent]!\?', 'uns\%[ilent]', 'redir\?!\?',
        \ '.*[^|]|',
        \ 'ld!\?', '[cl]fd!\?', '[cl]f\?do!\?',
        \ '\%(\%([.$]\|\d\+\)\%([,;]\%([.$]\|\d\+\)\)*\)\?\s*' .
        \ '\%(argdo\?!\?\|bufdo\?!\?\|windo\?\|tabdo\?\)' ]
endif
let s:range_pattern =  '\v(%('
      \ . '%(\%|[`''][.\^''"{}()<>[\][:alnum:]]|[.$]|\d+|\\[/?&]|/.+/?|\?.+\??)%([+\-]\d*)*'
      \ . '%(\s*[,;]\s*%([`''][.\^''"(){}<>[\][:alnum:]]|[.$]|\d+|\\[/?&]|/.+/|/?.+/?)%([+\-]\d*)*)*'
      \ . ')|)\s*'

command! -nargs=+ Alias   :call CmdAlias(<f-args>)
command! -nargs=+ UnAlias :call UnAlias(<f-args>)
command! -nargs=* Aliases :call <SID>Aliases(<f-args>)

if !exists('g:cmdalias_aliases')
  let g:cmdalias_aliases = {}
endif

" Sadly, these autocmd's cannot ensure that b:cmdalias_aliases is defined.
" augroup cmdalias
"   autocmd!
"   autocmd CmdWinEnter,BufNew,BufReadPre * let b:cmdalias_aliases = {}
" augroup end
" silent doautocmd cmdalias BufNew,BufReadPre *

" Define a new command alias.
function! CmdAlias(...)
  if a:0 is 0
    echoerr 'Neither <lhs> nor <rhs> specified for alias'
    return
  endif

  if a:0 is 1
    echoerr 'No <rhs> specified for alias'
    return
  endif

  if a:0 > 4
    echoerr 'Too many parameters. Use Alias [-buffer] [-range] <lhs> <rhs>!'
    return
  endif

  let numparams = 0
  let range = 0
  let bufferlocal = 0

  let posparam = 1
  while posparam <= (a:0 - 2)
    exe 'let param = a:' . posparam
    let posparam += 1
    if param is# '-range'
      let numparams += 1 | let range = 1
    elseif param is# '-buffer'
      let numparams += 1 | let bufferlocal = 1
    else
      echoerr 'Only -range or -buffer allowed as optional parameters'
      return
    endif
  endwhile
  unlet posparam

  exe 'let lhs = a:' . (1 + numparams)
  exe 'let rhs = a:' . (2 + numparams)
  " double all single quotes so that cabbrev expression correctly interpeted
  let  rhs = substitute(rhs, "'", "''", 'g')
  let  rhs = substitute(rhs, '|', '<bar>', 'g')

  if lhs !~# '\v^((\w|_)*\W*$|\W+(\w|_)|\W+((\w|_)+\W+)+)$'
    echoerr 'The non-word characters in the alias name must: Either enclose the word characters Or be all last Or be all first and followed by at most one word character!'
    return
  endif

  if has_key(g:cmdalias_aliases, rhs)
    echoerr "Another alias can't be used as <rhs>"
    return
  endif

  exec 'cnoreabbr <expr>' . (bufferlocal ? '<buffer>' : '') . ' ' . lhs .
        \ " <SID>ExpandAlias('" . lhs . "', '" . rhs . "', " . string(range) . ', ' . string(bufferlocal) . ')'
  if bufferlocal 
    if !exists('b:cmdalias_aliases') | let b:cmdalias_aliases = {} | endif
    let b:cmdalias_aliases[lhs] = rhs
  else
    let g:cmdalias_aliases[lhs] = rhs
  endif
endfunction

function! s:ExpandAlias(lhs, rhs, range, bufferlocal)
  " Check whether we are in command line
  if getcmdtype() isnot# ':'
    return a:lhs
  endif

  " Check whether cursor is at start of commandline
  let partCmd = strpart(getcmdline(), 0, getcmdpos()-1)
  let alias_pattern = '\V' . escape(a:lhs,'\')
  let prefixes_pattern = '\m\s*\%(\%(\m' . join(g:cmdaliasCmdPrefixes, '\|\m') . '\)\s\+\)*'
  if partCmd !~# '\m^' . prefixes_pattern . (a:range ? s:range_pattern : '') . alias_pattern . '\m$'
    return a:lhs
  endif

  if eval(a:bufferlocal)
    if !exists('b:cmdalias_aliases') | let b:cmdalias_aliases = {} | endif
    let aliases  = b:cmdalias_aliases
  else
    let aliases = g:cmdalias_aliases
  endif

  " Check whether LHS plus trigger char is the LHS of another Alias.
  " For example, with 'Alias F' and 'Alias F.', and '.' not in 'iskeyword',
  " typing '.' after 'F' already triggers the RHS of 'Alias F'.
  let trigger = nr2char(getchar(1))
  if !empty(trigger) && trigger isnot# ' '
    let lhs = a:lhs . trigger
    let len_lhs = len(lhs)
    if !empty(filter(keys(aliases), 'v:val[0:len_lhs-1] is# lhs && v:val isnot# a:lhs'))
      return a:lhs
    endif
  endif

  return a:rhs
endfunction

function! UnAlias(...)
  if a:0 > 0 && a:1 is# '-buffer'
    let bufferlocal = 1
    if !exists('b:cmdalias_aliases') | let b:cmdalias_aliases = {} | endif
    let aliases  = b:cmdalias_aliases
    let list     = copy(a:000[1:])
    let numparams = a:0-1
  else
    let bufferlocal = 0
    let aliases  = g:cmdalias_aliases
    let list     = copy(a:000)
    let numparams = a:0
  endif

  if numparams == 0
    echoerr 'No aliases specified'
    return
  endif

  let aliasesToRemove = filter(list, 'has_key(aliases, v:val) != 0')
  "let aliasesToRemove = map(filter(aliases, 'index(list, v:val[0]) != -1'), 'v:val[0]')
  if len(aliasesToRemove) != numparams
    let badAliases = filter(list, 'index(aliasesToRemove, v:val) == -1')
    echoerr 'No such aliases: ' . join(badAliases, ' ')
    return
  endif
  for alias in aliasesToRemove
    exec 'cunabbrev ' . (bufferlocal ? '<buffer>' : '') . ' ' . alias
  endfor
  call filter(aliases, 'index(aliasesToRemove, v:key) == -1')
endfunction

function! s:Aliases(...)
  if a:0 > 0 && a:1 is# '-buffer'
    if !exists('b:cmdalias_aliases') | let b:cmdalias_aliases = {} | endif
    let aliases  = b:cmdalias_aliases
    let list     = copy(a:000[1:])
    let numparams = a:0-1
  else
    let aliases  = g:cmdalias_aliases
    let list     = copy(a:000)
    let numparams = a:0
  endif

  if numparams == 0
    let goodAliases = keys(aliases)
  else
    let goodAliases = filter(list, 'has_key(aliases, v:val) != 0')
  endif

  if len(goodAliases) > 0
    let maxLhsLen = max(map(copy(goodAliases), 'strlen(v:val[0])'))
    echo join(map(copy(goodAliases), 'printf("%-" . maxLhsLen . "s %s\n", v:val, aliases[v:val])'), '')
  endif
endfunction

" Restore cpo.
let &cpo = s:save_cpo
unlet s:save_cpo

" ex:fdm=syntax sw=2

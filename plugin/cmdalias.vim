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
command! -nargs=* UnAlias :call UnAlias(<f-args>)
command! -nargs=* Aliases :call <SID>Aliases(<f-args>)

if ! exists('s:aliases')
  let s:aliases = {}
endif

" Define a new command alias.
function! CmdAlias(...)
  if a:0 is 0
    echohl ErrorMsg | echo 'Neither <lhs> nor <rhs> specified for alias' | echohl NONE
    return
  endif

  if a:0 is 1
    echohl ErrorMsg | echo 'No <rhs> specified for alias' | echohl NONE
    return
  endif

  if a:0 > 4
    echohl ErrorMsg | echo 'Too many parameters. Use Alias [-buffer] [-range] <lhs> <rhs>!' | echohl NONE
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
      echohl ErrorMsg | echo 'Only -range or -buffer allowed as optional parameters' | echohl NONE
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
    echohl ErrorMsg | echoerr 'The non-word characters in the alias name must: Either enclose the word characters Or be all last Or be all first and followed by at most one word character!' | echohl NONE
    return
  endif

  if has_key(s:aliases, rhs)
    echohl ErrorMsg | echo "Another alias can't be used as <rhs>" | echohl NONE
    return
  endif

  exec 'cnoreabbr <expr>' . (bufferlocal ? '<buffer>' : '') . ' ' . lhs .
        \ " <SID>ExpandAlias('" . lhs . "', '" . rhs . "', " . string(range) . ')'
  let s:aliases[lhs] = rhs
endfunction

function! s:ExpandAlias(lhs, rhs, range)
  let prefixes_pattern = '\m\s*\%(\%(\m' . join(g:cmdaliasCmdPrefixes, '\|\m') . '\)\s\+\)*'

  if getcmdtype() is# ':'
    " Determine if we are at the start of the command-line.
    " getcmdpos() is 1-based.
    let partCmd = strpart(getcmdline(), 0, getcmdpos()-1)
    let alias_pattern = '\V' . escape(a:lhs,'\')

    " Check that the lhs with the trigger char is not used in an abbreviation
    " itself, i.e. with alias 'F' and 'F.', and '.' not in 'iskeyword', typing
    " '.' would trigger the expansion of 'F' already.
    let trigger = getchar(1)
    if trigger && trigger != 32  " space
      let trigger_char = nr2char(trigger)
      let lhs = a:lhs.trigger_char
      let len_lhs = len(lhs)
      if len(filter(keys(s:aliases), "v:val[0:len_lhs-1] ==# lhs"))
        return a:lhs
      endif
    endif
    if partCmd =~# '\m^' . prefixes_pattern . (a:range ? s:range_pattern : '') . alias_pattern . '\m$'
      return a:rhs
    endif
  endif
  return a:lhs
endfunction

function! UnAlias(...)
  if a:0 == 0
    echohl ErrorMsg | echo 'No aliases specified' | echohl NONE
    return
  endif

  let aliasesToRemove = filter(copy(a:000), 'has_key(s:aliases, v:val) != 0')
  "let aliasesToRemove = map(filter(copy(s:aliases), 'index(a:000, v:val[0]) != -1'), 'v:val[0]')
  if len(aliasesToRemove) != a:0
    let badAliases = filter(copy(a:000), 'index(aliasesToRemove, v:val) == -1')
    echohl ErrorMsg | echo 'No such aliases: ' . join(badAliases, ' ') | echohl NONE
    return
  endif
  for alias in aliasesToRemove
    exec 'cunabbr' alias
  endfor
  call filter(s:aliases, 'index(aliasesToRemove, v:key) == -1')
endfunction

function! s:Aliases(...)
  if a:0 == 0
    let goodAliases = keys(s:aliases)
  else
    let goodAliases = filter(copy(a:000), 'has_key(s:aliases, v:val) != 0')
  endif
  if len(goodAliases) > 0
    let maxLhsLen = max(map(copy(goodAliases), 'strlen(v:val[0])'))
    echo join(map(copy(goodAliases), 'printf("%-" . maxLhsLen . "s %s", v:val, s:aliases[v:val])'), '\n')
  endif
endfunction

" Restore cpo.
let &cpo = s:save_cpo
unlet s:save_cpo

" ex:fdm=syntax sw=2

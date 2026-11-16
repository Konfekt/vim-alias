let s:save_cpo = &cpoptions
set cpoptions&vim

if !exists('g:cmdalias_aliases')
  let g:cmdalias_aliases = {}
endif

let s:range_pattern =  '\v(%('
      \ . '%(\%|[`''][.\^''"{}()<>[\][:alnum:]]|[.$]|\d+|\\[/?&]|/.+/?|\?.+\??)%([+\-]\d*)*'
      \ . '%(\s*[,;]\s*%([`''][.\^''"(){}<>[\][:alnum:]]|[.$]|\d+|\\[/?&]|/.+/?|\?.+\??)%([+\-]\d*)*)*'
      \ . ')|)\s*'

" Escape {str} for use inside a :cnoreabbrev or :cunabbrev command, where a
" '|' would end the command.
function! s:escape(str) abort
  return substitute(a:str, '|', '<bar>', 'g')
endfunction

" Split off a leading '-buffer' from {args}.
" Returns [bufferlocal, aliases dictionary, remaining arguments].
function! s:target(args) abort
  if !empty(a:args) && a:args[0] is# '-buffer'
    if !exists('b:cmdalias_aliases')
      let b:cmdalias_aliases = {}
    endif
    return [1, b:cmdalias_aliases, a:args[1:]]
  endif
  return [0, g:cmdalias_aliases, copy(a:args)]
endfunction

" alias#alias([-range], [-buffer], {lhs}, {rhs}): like :Alias.
function! alias#alias(...) abort
  return call('alias#define', [0] + a:000)
endfunction

" alias#define({bang}, [-range], [-buffer], {lhs}, {rhs}): like :Alias[!].
function! alias#define(bang, ...) abort
  if a:0 == 0
    echoerr 'Neither <lhs> nor <rhs> specified for alias'
    return
  endif
  if a:0 == 1
    echoerr 'No <rhs> specified for alias'
    return
  endif
  if a:0 > 4
    echoerr 'Too many parameters. Use Alias [-buffer] [-range] <lhs> <rhs>!'
    return
  endif

  let args = copy(a:000)
  let range = 0
  let bufferlocal = 0
  while len(args) > 2
    let param = remove(args, 0)
    if param is# '-range'
      let range = 1
    elseif param is# '-buffer'
      let bufferlocal = 1
    else
      echoerr 'Only -range or -buffer allowed as optional parameters'
      return
    endif
  endwhile
  let [lhs, rhs] = args

  if lhs !~# '\v^(\w*\W*$|\W+\w|\W+(\w+\W+)+)$'
    echoerr 'The non-word characters in the alias name must: Either enclose the word characters Or be all last Or be all first and followed by at most one word character!'
    return
  endif

  if bufferlocal
    if !exists('b:cmdalias_aliases')
      let b:cmdalias_aliases = {}
    endif
    let aliases = b:cmdalias_aliases
  else
    let aliases = g:cmdalias_aliases
  endif

  if !a:bang && has_key(aliases, lhs)
    if aliases[lhs] isnot# rhs
      echoerr 'There is already a different ' . (bufferlocal ? 'buffer-local' : 'global') . ' alias ' . lhs
    endif
    return
  endif

  execute 'cnoreabbrev <expr>' . (bufferlocal ? '<buffer>' : '') s:escape(lhs)
        \ s:escape(printf('alias#expand(%s, %s, %d, %d)', string(lhs), string(rhs), range, bufferlocal))
  let aliases[lhs] = rhs
endfunction

function! alias#expand(lhs, rhs, range, bufferlocal) abort
  if getcmdtype() isnot# ':'
    return a:lhs
  endif

  " Only expand if the alias is the command name, possibly preceded by
  " command modifiers and, for -range aliases, a range.
  let partCmd = strpart(getcmdline(), 0, getcmdpos() - 1)
  let alias_pattern = '\V' . escape(a:lhs, '\')
  let prefixes_pattern = '\m\s*\%(\%(\m' . join(g:cmdalias_cmdprefixes, '\|\m') . '\)\s\+\)*'
  if partCmd !~# '\m^' . prefixes_pattern . (a:range ? s:range_pattern : '') . alias_pattern . '\m$'
    return a:lhs
  endif

  if a:bufferlocal
    let aliases = get(b:, 'cmdalias_aliases', {})
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
    if !empty(filter(keys(aliases), 'v:val[0 : len_lhs - 1] is# lhs && v:val isnot# a:lhs'))
      return a:lhs
    endif
  endif

  return a:rhs
endfunction

" alias#unalias([-buffer], {lhs}...): like :UnAlias.
function! alias#unalias(...) abort
  let [bufferlocal, aliases, names] = s:target(a:000)
  if empty(names)
    echoerr 'No aliases specified'
    return
  endif

  let missing = filter(copy(names), '!has_key(aliases, v:val)')
  if !empty(missing)
    echoerr 'No such aliases: ' . join(missing)
    return
  endif

  for name in names
    if has_key(aliases, name)
      silent! execute 'cunabbrev' . (bufferlocal ? ' <buffer>' : '') s:escape(name)
      call remove(aliases, name)
    endif
  endfor
endfunction

function! s:contains_any(str, texts) abort
  for text in a:texts
    if stridx(a:str, text) >= 0
      return 1
    endif
  endfor
  return 0
endfunction

" alias#aliases([-buffer], [text]...): like :Aliases; list the aliases whose
" names contain any of the given texts, or all aliases if none is given.
function! alias#aliases(...) abort
  let [bufferlocal, aliases, texts] = s:target(a:000)
  let names = sort(keys(aliases))
  if !empty(texts)
    call filter(names, 's:contains_any(v:val, texts)')
  endif
  if empty(names)
    return
  endif

  let width = max(map(copy(names), 'strdisplaywidth(v:val)'))
  let lines = []
  for name in names
    call add(lines, name . repeat(' ', width - strdisplaywidth(name)) . ' ' . aliases[name])
  endfor
  echo join(lines, "\n")
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

let s:range_pattern =  '\v(%('
      \ . '%(\%|[`''][.\^''"{}()<>[\][:alnum:]]|[.$]|\d+|\\[/?&]|/.+/?|\?.+\??)%([+\-]\d*)*'
      \ . '%(\s*[,;]\s*%([`''][.\^''"(){}<>[\][:alnum:]]|[.$]|\d+|\\[/?&]|/.+/?|\?.+\??)%([+\-]\d*)*)*'
      \ . ')|)\s*'

function! alias#expand(lhs, rhs, range, bufferlocal)
  " Check whether we are in command line
  if getcmdtype() isnot# ':'
    return a:lhs
  endif

  " Check whether cursor is at start of commandline
  let partCmd = strpart(getcmdline(), 0, getcmdpos()-1)
  let alias_pattern = '\V' . escape(a:lhs,'\')
  let prefixes_pattern = '\m\s*\%(\%(\m' . join(g:cmdalias_cmdprefixes, '\|\m') . '\)\s\+\)*'
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

function! alias#unalias(...)
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

function! alias#aliases(...)
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


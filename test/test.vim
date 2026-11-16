" Headless tests for vim-alias.
" Run with test/run.sh, or:
"   vim -N -u NONE -i NONE --not-a-term -S test/test.vim
"   nvim --headless -u NONE -i NONE -S test/test.vim
" Results are written to the file in $ALIAS_TEST_OUT (default:
" test/result.txt); Vim exits with status 1 if any test fails.

let s:root = fnamemodify(expand('<sfile>:p'), ':h:h')
let s:out = empty($ALIAS_TEST_OUT) ? s:root . '/test/result.txt' : $ALIAS_TEST_OUT

let &runtimepath = s:root . ',' . &runtimepath
execute 'source' fnameescape(s:root . '/plugin/alias.vim')
set noswapfile hidden

let s:log = []
let s:failed = 0

function! s:Check(name, got, want) abort
  if a:got ==# a:want
    call add(s:log, 'ok   ' . a:name)
  else
    let s:failed += 1
    call add(s:log, 'FAIL ' . a:name . ': got ' . string(a:got) . ', want ' . string(a:want))
  endif
endfunction

" Run {cmd} and return the error it raised, or '' if none.
function! s:Error(cmd) abort
  try
    execute a:cmd
  catch
    return v:exception
  endtry
  return ''
endfunction

function! GrabCmdline() abort
  let g:alias_cmdline = getcmdline()
  return ''
endfunction

" Type {keys} on the ':' command line and return the command line as it
" reads afterwards, without executing it.
function! s:Typed(keys) abort
  let g:alias_cmdline = '<none>'
  call feedkeys(':' . a:keys . "\<C-\>eGrabCmdline()\<CR>\<Esc>", 'xt')
  return g:alias_cmdline
endfunction

" Remove every alias so that tests start from scratch.
function! s:Reset() abort
  silent! cabclear
  silent! cabclear <buffer>
  let g:cmdalias_aliases = {}
  let b:cmdalias_aliases = {}
endfunction

function! s:TestBasicExpansion() abort
  call s:Reset()
  Alias th tab\ help
  call s:Check('expands at start', s:Typed('th '), 'tab help ')
  call s:Check('expands after prefix', s:Typed('silent! th '), 'silent! tab help ')
  call s:Check('no expansion as argument', s:Typed('echo th '), 'echo th ')
  call s:Check('no range without -range', s:Typed('1,2th '), '1,2th ')
  Alias -range dg diffget
  call s:Check('-range expands after range', s:Typed("'<,'>dg "), "'<,'>diffget ")
endfunction

function! s:TestBufferLocal() abort
  call s:Reset()
  Alias -buffer spl setlocal\ spell
  call s:Check('buffer-local expands', s:Typed('spl '), 'setlocal spell ')
  enew!
  call s:Check('buffer-local not in other buffer', s:Typed('spl '), 'spl ')
  bwipeout!
endfunction

function! s:TestRedefine() abort
  call s:Reset()
  Alias th tab\ help
  call s:Check('same alias again is fine', s:Error('Alias th tab\ help'), '')
  call s:Check('different alias needs !', s:Error('Alias th tab\ new') =~# 'already a different global alias', 1)
  Alias! th tab\ new
  call s:Check('! overrides', s:Typed('th '), 'tab new ')
endfunction

" With 'Alias F' and 'Alias F.', typing '.' after 'F' must not expand 'F'.
function! s:TestPrefixOfOther() abort
  call s:Reset()
  Alias F echo\ 'F'
  Alias F. echo\ 'F.'
  call s:Check('shorter alias', s:Typed('F '), "echo 'F' ")
  call s:Check('longer alias', s:Typed('F. '), "echo 'F.' ")
endfunction

" A '|' in the <rhs> must not end the :cnoreabbrev command.
function! s:TestBarInRhs() abort
  call s:Reset()
  Alias sp2 set\ spell|set\ nospell
  call s:Check('bar in rhs', s:Typed('sp2 '), 'set spell|set nospell ')
endfunction

" Bug: a quote in the <rhs> was shown doubled by :Aliases, and redefining
" the same alias compared against the doubled form.
function! s:TestQuoteInRhs() abort
  call s:Reset()
  Alias ln echo\ line('.')
  call s:Check('quote in rhs expands', s:Typed('ln '), "echo line('.') ")
  call s:Check('quote in rhs listed as typed', g:cmdalias_aliases, {'ln': "echo line('.')"})
  call s:Check('quote in rhs: same again is fine', s:Error("Alias ln echo\\ line('.')"), '')
endfunction

" Bug: an <lhs> with a quote broke the abbreviation's expression.
function! s:TestQuoteInLhs() abort
  call s:Reset()
  Alias x' echo\ 'x'
  call s:Check('quote in lhs expands', s:Typed("x' "), "echo 'x' ")
endfunction

" Bug: an <lhs> with a '|' ended the :cnoreabbrev command early.
function! s:TestBarInLhs() abort
  call s:Reset()
  Alias x| echo\ 'bar'
  call s:Check('bar in lhs expands', s:Typed('x| '), "echo 'bar' ")
  UnAlias x|
  call s:Check('bar in lhs removed', s:Typed('x| '), 'x| ')
endfunction

" Bug: :UnAlias did not name the unknown aliases in its error.
function! s:TestUnAlias() abort
  call s:Reset()
  Alias th tab\ help
  Alias -buffer spl setlocal\ spell
  call s:Check('unknown alias named', s:Error('UnAlias th nosuch'), 'Vim(echoerr):No such aliases: nosuch')
  call s:Check('nothing removed on error', sort(keys(g:cmdalias_aliases)), ['th'])
  UnAlias th
  call s:Check('removed from list', g:cmdalias_aliases, {})
  call s:Check('no longer expands', s:Typed('th '), 'th ')
  UnAlias -buffer spl
  call s:Check('buffer-local removed', b:cmdalias_aliases, {})
  call s:Check('buffer-local no longer expands', s:Typed('spl '), 'spl ')
  call s:Check('no names', s:Error('UnAlias -buffer'), 'Vim(echoerr):No aliases specified')
endfunction

" Bug: :Aliases did not align the <rhs> column, and only listed exact names
" though the docs say it lists names containing the given text.
function! s:TestAliases() abort
  call s:Reset()
  Alias th tab\ help
  Alias gbl Silent\ tig\ blame
  Alias g Silent\ git
  call s:Check('list all, sorted and aligned', split(execute('Aliases'), "\n"),
        \ ['g   Silent git', 'gbl Silent tig blame', 'th  tab help'])
  call s:Check('list containing', split(execute('Aliases b'), "\n"), ['gbl Silent tig blame'])
  call s:Check('list exact name', split(execute('Aliases th'), "\n"), ['th tab help'])
  call s:Check('list none', split(execute('Aliases nosuch'), "\n"), [])
  Alias -buffer spl setlocal\ spell
  call s:Check('list buffer-local', split(execute('Aliases -buffer'), "\n"), ['spl setlocal spell'])
endfunction

" Bug: the documented function alias#alias() did not exist.
function! s:TestFunction() abort
  call s:Reset()
  call s:Check('alias#alias defines', s:Error("call alias#alias('-range', 'dg', 'diffget')"), '')
  call s:Check('alias#alias expands', s:Typed('1,2 dg '), '1,2 diffget ')
  call s:Check('Alias() still works', s:Error("call Alias(0, 'th', 'tab help')"), '')
  call s:Check('Alias() expands', s:Typed('th '), 'tab help ')
endfunction

function! s:TestArgErrors() abort
  call s:Reset()
  call s:Check('no rhs', s:Error('Alias th'), 'Vim(echoerr):No <rhs> specified for alias')
  call s:Check('bad option', s:Error('Alias -foo th x'), 'Vim(echoerr):Only -range or -buffer allowed as optional parameters')
  call s:Check('bad lhs', s:Error('Alias a!b c'), 'Vim(echoerr):The non-word characters in the alias name must: Either enclose the word characters Or be all last Or be all first and followed by at most one word character!')
endfunction

for s:test in ['BasicExpansion', 'BufferLocal', 'Redefine', 'PrefixOfOther', 'BarInRhs',
      \ 'QuoteInRhs', 'QuoteInLhs', 'BarInLhs', 'UnAlias', 'Aliases', 'Function', 'ArgErrors']
  try
    call call('s:Test' . s:test, [])
  catch
    let s:failed += 1
    call add(s:log, 'FAIL ' . s:test . ': ' . v:exception . ' @ ' . v:throwpoint)
  endtry
endfor

call add(s:log, s:failed ? s:failed . ' failed' : 'all passed')
call writefile(s:log, s:out)
execute (s:failed ? 'cquit!' : 'qall!')

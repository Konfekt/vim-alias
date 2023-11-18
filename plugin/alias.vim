if exists('g:loaded_cmdalias')
	finish
endif
if v:version < 700
	echomsg 'cmdalias: You need Vim 7.0 or higher'
	finish
endif
let g:loaded_cmdalias = 301

" Make sure line-continuations won't cause any problem. This will be restored
"		at the end
let s:save_cpo = &cpo
set cpo&vim

if !exists('g:cmdalias_cmdprefixes')
	let g:cmdalias_cmdprefixes = [
				\ '\%(vert\%[ical]\|hor\%[izontal]\|lefta\%[bove]\|abo\%[veleft]\|rightb\%[elow]\|bel\%[owright]\|to\%[pleft]\|bo\%[tright]\)\?\s*' .
				\ 'ter\%[minal]\s*' .
				\ '\%(++\%(close\|noclose\|open\|curwin\|hidden\|norestore\|shell\|kill=\a*\|rows=\d\+\|cols=\d\+\|eof=\S*\|pty=\a*\|api=\w\+\)\)\?',
				\ '\d*verb\%[ose]', 'debug', 'sil\%[ent]!\?', 'uns\%[ilent]', 'redir\?!\?',
				\ '.*[^|]|',
				\ 'ld!\?', '[cl]fd!\?', '[cl]f\?do!\?',
				\ '\%(\%([.$]\|\d\+\)\%([,;]\%([.$]\|\d\+\)\)*\)\?\s*' .
				\ '\%(argdo\?!\?\|bufdo\?!\?\|windo\?\|tabdo\?\)'
				\ ]
endif



function! Alias(bang, ...)
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

	if bufferlocal
		if !exists('b:cmdalias_aliases') | let b:cmdalias_aliases = {} | endif
	endif

	if !a:bang
		if bufferlocal && has_key(b:cmdalias_aliases, lhs)
			if b:cmdalias_aliases[lhs] isnot# rhs
				echoerr "There is already a different buffer-local alias " . lhs
			endif
			return
		endif
		if !bufferlocal && has_key(g:cmdalias_aliases, lhs)
			if g:cmdalias_aliases[lhs] isnot# rhs
				echoerr "There is already a different global alias " . lhs
			endif
			return
		endif
	endif

	exec 'cnoreabbr <expr>' . (bufferlocal ? '<buffer>' : '') . ' ' . lhs .
				\ " alias#expand('" . lhs . "', '" . rhs . "', " . string(range) . ', ' . string(bufferlocal) . ')'
	if bufferlocal
		let b:cmdalias_aliases[lhs] = rhs
	else
		let g:cmdalias_aliases[lhs] = rhs
	endif
endfunction

command! -nargs=+ -bang Alias		:call Alias(<bang>0, <f-args>)
command! -nargs=+				UnAlias :call alias#unalias(<f-args>)
command! -nargs=*				Aliases :call alias#aliases(<f-args>)

if !exists('g:cmdalias_aliases')
	let g:cmdalias_aliases = {}
endif

" Sadly, these autocmd's cannot ensure that b:cmdalias_aliases is defined.
" augroup cmdalias
"		autocmd!
"		autocmd CmdWinEnter,BufNew,BufReadPre * let b:cmdalias_aliases = {}
" augroup end
" silent doautocmd cmdalias BufNew,BufReadPre *

" Restore cpo.
let &cpo = s:save_cpo
unlet s:save_cpo

" ex:fdm=syntax sw=2

" Command-line aliases: abbreviations that only expand at the start of an Ex
" command.  See :help alias.

if exists('g:loaded_cmdalias')
  finish
endif
let g:loaded_cmdalias = 301

let s:save_cpo = &cpoptions
set cpoptions&vim

if !exists('g:cmdalias_cmdprefixes')
  let g:cmdalias_cmdprefixes = [
    \ '\%(vert\%[ical]\|hor\%[izontal]\|lefta\%[bove]\|abo\%[veleft]\|rightb\%[elow]\|bel\%[owright]\|to\%[pleft]\|bo\%[tright]\)', 'tab',
    \ 'conf\%[irm]', 'bro\%[wse]',
    \ '\%(keepa\%[lt]\|keepj\%[umps]\|kee\%[pmarks]\|keepp\%[atterns]\)', 'loc\%[kmarks]', 'nos\%[wapfile]',
    \ '\d*verb\%[ose]', 'debug', 'sil\%[ent]!\?', 'uns\%[ilent]', 'redir\?!\?',
    \ '.*[^|]|',
    \ 'ld!\?', '[cl]fd!\?', '[cl]f\?do!\?',
    \ '\%(\%([.$]\|\d\+\)\%([,;]\%([.$]\|\d\+\)\)*\)\?\s*' .
    \ '\%(argdo\?!\?\|bufdo\?!\?\|windo\?\|tabdo\?\)' ]
endif

if !exists('g:cmdalias_aliases')
  let g:cmdalias_aliases = {}
endif

" Kept for scripts that call it directly; see alias#define().
function! Alias(bang, ...) abort
  return call('alias#define', [a:bang] + a:000)
endfunction

command! -nargs=+ -bang Alias   call alias#define(<bang>0, <f-args>)
command! -nargs=+       UnAlias call alias#unalias(<f-args>)
command! -nargs=*       Aliases call alias#aliases(<f-args>)

let &cpoptions = s:save_cpo
unlet s:save_cpo

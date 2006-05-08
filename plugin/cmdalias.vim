" cmdalias.vim: Create aliases for Vim commands.
" Author: Hari Krishna Dara (hari_vim at yahoo dot com)
" Last Change: 20-Apr-2006 @ 11:35
" Created:     07-Jul-2003
" Requires: Vim-7.0 or higher
" Depends On: multvals.vim, genutils.vim
" Version: 2.0.1
" Licence: This program is free software; you can redistribute it and/or
"          modify it under the terms of the GNU General Public License.
"          See http://www.gnu.org/copyleft/gpl.txt 
" Download From:
"     http://www.vim.org/script.php?script_id=745
" Usage:
"     call CmdAlias('cheese', 'Cheese', [flags])
" Description:
"   - Vim doesn't allow us to create user-defined commands unless they start
"     with an uppercase letter. I find this annoying and constrained when it
"     comes to overriding built-in commands with my own. To override built-in
"     commands, we often have to create a new command that has the same name
"     as the built-in but starting with an uppercase letter (e.g., "Cd"
"     instead of "cd"), and remember to use that everytime (besides the
"     fact that typing uppercase letters take more effort). An alternative is
"     to use the :cabbr to create an abbreviation for the built-in command
"     (:cmap is not good) to the user-defined command (e.g., "cabbr cd Cd").
"     But this would generally cause more inconvenience because the
"     abbreviation gets expanded no matter where in the command-line you use
"     it. This is where the plugin comes to your rescue by arranging the cabbr
"     to expand only if typed as the first word in the command-line, in a
"     sense working like the aliases in csh or bash.
"   - The plugin provides a function to define command-line abbreviations such
"     a way that they are expanded only if they are typed as the first word of
"     a command (at ":" prompt). The same rules that apply to creating a
"     :cabbr apply to the second argument of CmdAlias() function too. You can
"     pass in optional flags (such as <buffer>) to the :cabbr command through
"     the third argument.
"   - The :cabbr's created this way, work like the bash aliases, except that
"     in this case, the alias is substituted in-place followed by the rules
"     mentioned in the |abbreviations|, and no aruments can be defined.
" TODO:
"   - It will be nice to recognize alias after certain vim commands that
"     take other commands as arguments, such as verbose or debug.

if exists("loaded_cmdalias")
  finish
endif
if v:version < 700
  echomsg "cmdalias: You need Vim 7.0 or higher"
  finish
endif
let loaded_cmdalias = 200

" Make sure line-continuations won't cause any problem. This will be restored
"   at the end
let s:save_cpo = &cpo
set cpo&vim

" Define a new command alias.
function! CmdAlias(lhs, rhs, ...)
  if a:0 > 0
    let flags = a:1.' '
  else
    let flags = ''
  endif
  exec 'cnoreabbr <expr> '.flags.a:lhs.
	\ " <SID>ExpandAlias('".a:lhs."', '".a:rhs."')"
endfunction

function! s:ExpandAlias(lhs, rhs)
  if getcmdtype() == ":"
    " Determine if we are at the start of the command-line.
    " getcmdpos() is 1-based.
    let firstWord = strpart(getcmdline(), 0, getcmdpos())
    if firstWord == a:lhs
      return a:rhs
    endif
  endif
  return a:lhs
endfunction

" Restore cpo.
let &cpo = s:save_cpo
unlet s:save_cpo

" vim6:fdm=marker sw=2

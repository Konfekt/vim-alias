" cmdalias.vim: Create aliases for Vim commands.
" Author: Hari Krishna <hari_vim@yahoo.com>
" Last Change: 14-Jul-2003 @ 20:00
" Created:     07-Jul-2003
" Requires: Vim-6.0 or higher, curcmdmode.vim(1.0)
" Version: 1.0.1
" Licence: This program is free software; you can redistribute it and/or
"          modify it under the terms of the GNU General Public License.
"          See http://www.gnu.org/copyleft/gpl.txt 
" Download From:
"     http://www.vim.org/script.php?script_id=745
" Usage:
"     call CmdAlias('cheese', 'Cheese')
" Description:
"   - The plugin provides a function to define command-line abbreviations such
"     a way that they are expanded only if they are typed at the first word of
"     a command (at ":" prompt).
"   - The :cabbr's created work like the bash aliases, except that in this
"     case, the alias is substituted in-place followed by the rules mentioned
"     in the |abbreviations|. Since, user-defined commands can not start with
"     a lowercase letter, these aliases can be used as an alternative way of
"     defining new commands that are easier to type (or just override Vim's
"     built-in commands with that of your own).
" WARNING:
"   - For some unknown reasons, Vim seems to expand the command-line
"     abbreviations when they occur as part of mappings typed on command-line,
"     and because of the way the plugin implements aliasing, this could fail
"     the map execution. E.g., say you defined a new :cabbr as
"
"	  :cabbr cheese Cheese
"
"     and say you or one of the plugins you installed, defined the
"     following mapping (you can actually try this first and the previous
"     command next on your command-line to see the issue in action):
"
"	  :nnoremap <F12> :call input('Say cheese:')<CR>
"
"     Now when you press <F12>, you can see that the message appears as 'Say
"     Cheese' instead of the expected 'Say cheese', this is because Vim
"     unexpectedly substituted 'cheese' with 'Cheese' because of the
"     previous abbreviation. This is an unexpected behavior and so until
"     the problem is fixed in Vim, care must be taken in choosing names for
"     aliases such that they are less likely to interfere with the mappings.
" TODO:
"   - I should avoid the screen from getting redrawn when the alias gets
"     expanded.

if exists("loaded_cmdalias")
  finish
endif
let loaded_cmdalias = 1

" Make sure line-continuations won't cause any problem. This will be restored
"   at the end
let s:save_cpo = &cpo
set cpo&vim

" Define a new command alias.
function! CmdAlias(lhs, rhs)
  exec "cabbr ".a:lhs." ".a:lhs.s:posMarker.
	\ "<Plug>CCMC-C<Plug>CCMCCM".
        \ "<Plug>CCMC-R=<SID>CmdAlias('".a:lhs."', '".a:rhs."')<Plug>CCMCR"
	\ .s:plugAbbrevMap."<Plug>CCMC-R=<SID>ClearAbbrevMap()<Plug>CCMCR"
endfunction


" Marker for the cursor position where the abbreviation got expanded.
let s:posMarker = "<>CuRpOs<>"
" WORK-AROUND for control keys in cabbr don't expand if returned from an expr.
" This is the map that will be assigned the number of <Left>'s needed to
"   position the cursor appropriately. This will initially (and after every
"   use) be mapped to nothing. This is set to something that is hard to be
"   typed, however I am making this very short-lived, so user shouldn't even
"   see it.
let s:plugAbbrevMap = "<>CmDaLiAs<>"

"
" Assumes that the command to-be-processed exists as the last item in the "cmd"
" history. Modifies the history to reflect the changes.
"
function! s:CmdAlias(lhs, rhs)
  let histList = ''
  if CCMGetCCM() == ":"
    let histList = "cmd"
  elseif CCMGetCCM() == "/" || CCMGetCCM() == "?"
    let histList = "search"
  endif
  if histList == '' " Just to be cautious.
    return rhs
  endif

  let newVal = histget(histList, -1)
  let curPos = stridx(newVal, s:posMarker)
  let newVal = substitute(newVal, s:posMarker, '', '')
  let nLeft = strlen(newVal) - curPos
  "echomsg "oldvalue = " . newVal
  call histdel(histList, -1)
  if newVal =~ '^'.a:lhs && curPos == strlen(a:lhs)
    let newVal = substitute(newVal, '^'.a:lhs, a:rhs, '')
    "echomsg "newvalue = " . newVal
    " Work-around for "C-C doesn't add the item to history from second time "
    " "onwards for some reason". I couldn't figure out why. But it now leaves a
    " copy in the history for the last used command mode, even if you cancel
    " the command.
    if histget(histList, -1) != newVal
      call histadd(histList, newVal)
    endif
  endif
  " This is the simplest and should have worked according to Vim's doc, but it
  " doesn't work. I reported the issue on Vim ML, but there was no fix/solution.
  "return newVal . s:MakeRepStr(nLeft, "\<Left>") " This doesn't work.
  if nLeft < 1
    exec "cnoremap " . s:plugAbbrevMap . ' <Nop>'
  else
    exec "cnoremap " . s:plugAbbrevMap . ' ' . s:MakeRepStr(nLeft, "<Left>")
  endif
  return newVal
endfunction

function! s:ClearAbbrevMap()
  silent! exec 'cunmap ' . s:plugAbbrevMap
  return ""
endfunction

function! s:MakeRepStr(nRep, str)
  let i = 0
  let leftStr = ''
  while i < a:nRep
    let leftStr = leftStr . a:str
    let i = i + 1
  endwhile
  return leftStr
endfunction

" Restore cpo.
let &cpo = s:save_cpo
unlet s:save_cpo

" vim6:fdm=marker sw=2

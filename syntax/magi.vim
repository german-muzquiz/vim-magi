" Syntax highlighting for Magi buffers
if exists('b:current_syntax') | finish | endif

" Highlight lines starting with //
syntax region magiComment start="\%^" end=/^-----------------------------------------------------------------$/

" Link to standard comment highlighting
hi def link magiComment Comment

let b:current_syntax = 'magi'

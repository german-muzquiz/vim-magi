" Syntax highlighting for Magi buffers
if exists('b:current_syntax') | finish | endif

syntax region magiHeader start="\%^" end=/^-------------------------------------------------------------------------------------$/
syntax match magiDivider /^-------------------------------------------------------------------------------------$/
syntax match filePathReference /^@.*/ 

highlight default link magiHeader Comment
highlight default link magiDivider Comment
highlight default link filePathReference Identifier

let b:current_syntax = 'magi'

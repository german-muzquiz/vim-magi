" AI coding assitant capabilities for vim

if exists('g:magi_loaded')
    finish
endif
let g:magi_loaded = 1

" Auto-install on first load
call magi#init_if_needed()

" Commands
command! MagiConfig call magi#config()
command! Magi call magi#chat()
command! MagiPlan call magi#plan()
command! MagiExecute call magi#unimplemented()
command! MagiDebug call magi#unimplemented()

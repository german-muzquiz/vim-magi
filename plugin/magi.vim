" AI coding assitant capabilities for vim

if exists('g:magi_loaded')
    finish
endif
let g:magi_loaded = 1

" Auto-install on first load
call magi#init_if_needed()


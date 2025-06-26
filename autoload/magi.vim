
let s:magi_home = expand('~/.magi')

" Install the magi python backend if not already installed
function! magi#install_if_needed() abort
    let l:plugin_dir = fnamemodify(resolve(expand('<sfile>:p')), ':h:h')
    let l:python_source = l:plugin_dir . '/magi'

    " Check if installation is needed
    if !isdirectory(s:magi_home) || !filereadable(s:magi_home . '/magi/pyproject.toml')
        echo "Installing vim-magi Python backend..."
        call s:install(l:python_source, s:magi_home)
        echo "vim-magi installation complete!"
    endif
endfunction

" Install the magi python backend
function! s:install(source, dest) abort
    " Create destination directory
    if !isdirectory(a:dest)
        call mkdir(a:dest, 'p')
    endif

    " Copy Python files
    if has('win32') || has('win64')
        " Windows
        let l:cmd = 'xcopy /E /I /Y "' . a:source . '" "' . a:dest . '"'
    else
        " Unix/Linux/macOS
        let l:cmd = 'cp -r "' . a:source . '/." "' . a:dest . '/"'
    endif

    let l:result = system(l:cmd)
    if v:shell_error != 0
        echoerr "Failed to copy Python backend: " . l:result
    endif
endfunction

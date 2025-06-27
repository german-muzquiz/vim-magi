
let s:magi_home = expand('~/.magi')
let s:magi_settings = expand('~/.magi') . '/config.yml'

" Initialize the installation if needed
function! magi#init_if_needed() abort
    if !isdirectory(s:magi_home) || !filereadable(s:magi_settings)
        let l:plugin_dir = fnamemodify(resolve(expand('<sfile>:p')), ':h:h')

        if l:plugin_dir =~ 'script '
            " We're in vim-plug context, extract the path
            let l:plugin_dir = matchstr(l:plugin_dir, 'script \zs\S*')
        endif

        echom "Installing vim-magi Python backend..."
        call s:install(l:plugin_dir, s:magi_home . '/magi')
    endif
endfunction

" Install the magi python backend
function! s:install(source, dest) abort
    let l:python_home = a:source . '/magi'

    " Create destination directory
    if !isdirectory(a:dest)
        call mkdir(a:dest, 'p')
    endif

    " Copy Python files
    if has('win32') || has('win64')
        " Windows
        let l:cmd = 'xcopy /E /I /Y "' . l:python_home . '" "' . a:dest . '"'
    else
        " Unix/Linux/macOS
        let l:cmd = 'cp -r "' . l:python_home . '/." "' . a:dest . '/"'
    endif

    let l:result = system(l:cmd)
    if v:shell_error != 0
        echoerr "Failed to copy Python backend: " . l:result
        return
    endif

    " Copy settings file
    let l:script_dir = l:python_home . '/autoload'
    let l:result = system('cp "' . l:script_dir . '/magi/config.yml.template" ' . s:magi_settings . '"')
endfunction

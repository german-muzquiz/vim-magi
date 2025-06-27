
let s:magi_home = expand('~/.magi')
let s:magi_settings = expand('~/.magi') . '/config.yml'

" Initialize the installation if needed
function! magi#init_if_needed() abort
    if !isdirectory(s:magi_home) || !filereadable(s:magi_settings)
        let l:plugin_dir = fnamemodify(resolve(expand('<sfile>:p')), ':h:h')
        echom 'Plugin directory: ' . l:plugin_dir

        if l:plugin_dir =~ 'script '
            echom "Inside vim-plug context"
            " We're in vim-plug context, extract the path
            let s:plugin_dir = matchstr(l:plugin_dir, 'script \zs\S*')
        endif

        let l:python_source = l:plugin_dir . '/magi'
        echom "Python source: " . l:python_source

        echom "Installing vim-magi Python backend..."
        call s:install(l:python_source, s:magi_home . '/magi')
    endif
endfunction

" Install the magi python backend
function! s:install(source, dest) abort
    echom "Source: " . a:source . ", Destination: " . a:dest
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
        return
    endif

    " Copy settings file
    let l:script_dir = resolve(expand('<sfile>:p'))
    echom "Script dir: " . l:script_dir
    let l:result = system('cp "' . l:script_dir . '/magi/config.yml.template" ' . s:magi_settings . '"')
endfunction

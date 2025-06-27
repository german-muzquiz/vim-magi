
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

        echom "Initializing magi in " . s:magi_home
        call magi#init(l:plugin_dir, s:magi_home . '/magi')
    endif
endfunction


" Install the magi python backend
function! magi#init() abort
    let l:plugin_dir = fnamemodify(resolve(expand('<sfile>:p')), ':h')

    if l:plugin_dir =~ 'script '
        " We're in vim-plug context, extract the path
        let l:plugin_dir = matchstr(l:plugin_dir, 'script \zs\S*')
    endif

    echom 'Plugin directory: ' . l:plugin_dir
    let l:python_home = l:plugin_dir . '/magi'

    " Create destination directory
    if !isdirectory(s:magi_home . '/magi')
        call mkdir(s:magi_home . '/magi', 'p')
    endif

    " Copy Python files
    let l:src = l:python_home
    let l:dst = s:magi_home . '/magi'
    if has('win32') || has('win64')
        " Windows
        let l:cmd = 'xcopy /E /I /Y "' . l:src . '" "' . l:dst . '"'
    else
        " Unix/Linux/macOS
        let l:cmd = 'cp -r "' . l:src . '/." "' . l:dst . '/"'
    endif
    echom 'Running: ' . l:cmd

    let l:result = system(l:cmd)
    if v:shell_error != 0
        echoerr "Failed to copy Python backend: " . l:result
        return
    endif

    " Copy settings file
    let l:script_dir = l:plugin_dir . '/autoload'
    if has('win32') || has('win64')
        " Windows
        let l:cmd = 'xcopy /E /I /Y "' . l:script_dir . '/magi/config.yml.template" "' . s:magi_settings . '"'
    else
        " Unix/Linux/macOS
        let l:cmd = 'cp "' . l:script_dir . '/magi/config.yml.template" "' . s:magi_settings . '"'
    endif

    let l:result = system(l:cmd)
    if v:shell_error != 0
        echoerr "Failed to copy settings file: " . l:result
        return
    endif
endfunction

" Open the config file
function! magi#config() abort
    execute 'edit ' . s:magi_settings
endfunction

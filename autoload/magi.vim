
" Global variables
let g:magi_chat_tab_id = -1

let s:magi_home = expand('~/.magi')
let s:magi_settings = expand('~/.magi') . '/config.json'
let s:magi_last_active_tab = -1

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

    let l:result = system(l:cmd)
    if v:shell_error != 0
        echoerr "Failed to copy Python backend: " . l:result
        return
    endif

    " Copy settings file
    let l:script_dir = l:plugin_dir . '/autoload'
    if has('win32') || has('win64')
        " Windows
        let l:cmd = 'xcopy /E /I /Y "' . l:script_dir . '/magi/config.json.template" "' . s:magi_settings . '"'
    else
        " Unix/Linux/macOS
        let l:cmd = 'cp "' . l:script_dir . '/magi/config.json.template" "' . s:magi_settings . '"'
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


" --- Config handling ---

" Load and parse configuration from JSON file
function! s:load_config() abort
    if !filereadable(s:magi_settings)
        echoerr "Magi: Configuration file not found at " . s:magi_settings
        return {}
    endif

    try
        let l:content = readfile(s:magi_settings)
        let l:json_str = join(l:content, "\n")
        let l:config = json_decode(l:json_str)
        
        " Expand environment variables
        call s:expand_env_vars(l:config)
        
        return l:config
    catch
        echoerr "Magi: Failed to parse configuration file: " . v:exception
        return {}
    endtry
endfunction


" Recursively expand environment variables in configuration
function! s:expand_env_vars(data) abort
    if type(a:data) == type({})
        " Dictionary
        for l:key in keys(a:data)
            call s:expand_env_vars(a:data[l:key])
        endfor
    elseif type(a:data) == type([])
        " List
        for l:i in range(len(a:data))
            call s:expand_env_vars(a:data[l:i])
        endfor
    elseif type(a:data) == type("")
        " String - check for environment variables
        let l:expanded = expand(a:data)
        " Handle ${VAR} format
        while l:expanded =~ '\${[^}]\+}'
            let l:var_match = matchstr(l:expanded, '\${[^}]\+}')
            let l:var_name = substitute(l:var_match, '\${', '', '')
            let l:var_name = substitute(l:var_name, '}', '', '')
            let l:var_value = getenv(l:var_name)
            if l:var_value != v:null
                let l:expanded = substitute(l:expanded, l:var_match, l:var_value, '')
            else
                break
            endif
        endwhile
        return l:expanded
    endif
endfunction


" --- Chat functionality ---

" Opens the Magi chat interface
function! magi#chat() abort
    let l:settings = s:load_config()
    if empty(l:settings)
        return
    endif
    
    let l:chat_cmd_config = get(get(get(l:settings, 'magi', {}), 'workflows', {}), 'chat', {})
    let l:chat_cmd = get(l:chat_cmd_config, 'cmd', 'cli/claude')

    if l:chat_cmd =~ '^cli/'
        call magi#launch_fullscreen_cli(substitute(l:chat_cmd, 'cli/', '', ''), 'Magi (claude)')
    else
        echom "Unsupported chat command: " . l:chat_cmd
    endif
endfunction


" Implementation for cli based chat
function! magi#launch_fullscreen_cli(command, tab_name) abort
    " Check if the Magi tab already exists and is valid
    if g:magi_chat_tab_id != -1 && len(tabpagebuflist(g:magi_chat_tab_id)) > 0 && getbufvar(tabpagebuflist(g:magi_chat_tab_id)[0], 'is_magi_term', 0)
        execute 'tabnext ' . g:magi_chat_tab_id
        call feedkeys("i", "n")
    else
        if !executable(split(a:command)[0])
            echoerr "Magi: '" . a:command . "' executable not found in your PATH."
            return
        endif

        let l:current_tab = tabpagenr()

        tabnew

        let g:magi_chat_tab_id = tabpagenr()

        try
            "execute 'terminal ++curwin ' . a:command
            let l:job = term_start(a:command, {
                \ 'curwin': 1,
                \ 'exit_cb': function('s:cleanup_terminal_tab')
                \ })
        catch
            echoerr "Magi: Failed to launch terminal command: " . a:command
            tabclose
            return
        endtry

        let b:is_magi_term = 1
        let b:magi_return_tab = l:current_tab

        " Set a friendly name for the tab/buffer
        silent file `=a:tab_name`
        setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted

        " Mappings to switch back to code
        tnoremap <buffer> <silent> <C-s> <C-\><C-n>:call <SID>switch_to_return_tab()<CR>
        nnoremap <buffer> <silent> <C-s> :call <SID>switch_to_return_tab()<CR>

        echom "Magi: Started session in new tab. Press Ctrl-s to switch back to your code."

        return l:job
    endif
endfunction


" Switch back to the last active editor tab
function! s:switch_to_return_tab() abort
    if exists('b:magi_return_tab') && len(tabpagebuflist(b:magi_return_tab)) > 0
        execute 'tabnext ' . b:magi_return_tab
    else
        " Original tab was closed, go to the previous one as a fallback
        tabprevious
    endif
endfunction


" Cleanup when the terminal process exits
function! s:cleanup_terminal_tab(job, exit_status) abort
    if tabpagenr() == g:magi_chat_tab_id
        let l:tab_to_close = g:magi_chat_tab_id
        let g:magi_chat_tab_id = -1 " Reset global var
        execute 'bdelete! '
        " Only close tab if it's not the last one
        if tabpagenr('$') > 1
            execute 'tabclose ' . l:tab_to_close
        endif
    endif
endfunction

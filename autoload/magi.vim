
" Global variables
" Stores tab IDs for different magi commands, e.g., {'chat': 1001, 'plan': 1002}
if !exists('g:magi_tabs')
    let g:magi_tabs = {}
endif

" Stores the key of the last run magi command, e.g., 'chat' or 'plan'
if !exists('g:magi_last_command')
    let g:magi_last_command = ''
endif

let s:magi_home = expand('~/.magi')
let s:magi_settings = expand('~/.magi') . '/config.json'


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


" --- Tab Management Functions ---

" Returns a valid tab ID for a given key, or -1 if not found/invalid.
" Cleans up stale entries from g:magi_tabs.
function! s:get_magi_tab(key) abort
    let l:tab_id = -1
    for l:tabnr in range(1, tabpagenr('$'))
        let l:buflist = tabpagebuflist(l:tabnr)
        for l:bufnr in l:buflist
            if getbufvar(l:bufnr, 'is_magi_tab', 0)
                let l:magi_key = getbufvar(l:bufnr, 'magi_key', '')
                if l:magi_key ==# a:key
                    let l:tab_id = l:tabnr
                    break
                endif
            endif
        endfor
    endfor

    if l:tab_id == -1
        return -1
    endif

    " Check if tab and its buffer still exist and is a magi tab
    if tabpagenr('$') >= l:tab_id && len(tabpagebuflist(l:tab_id)) > 0 && getbufvar(tabpagebuflist(l:tab_id)[0], 'is_magi_tab', 0)
        return l:tab_id
    else
        " Stale entry, remove it
        call remove(g:magi_tabs, a:key)
        return -1
    endif
endfunction

" Creates a new tab, registers it, and returns the new tab ID.
function! s:create_magi_tab(key) abort
    tabnew
    let l:new_tab_id = tabpagenr()

    " Register the new tab
    let g:magi_tabs[a:key] = l:new_tab_id

    return l:new_tab_id
endfunction

" --- Plan functionality ---

" Opens the Magi plan interface
function! magi#plan() abort
    let g:magi_last_command = 'plan'
    
    let l:settings = s:load_config()
    if empty(l:settings)
        return
    endif
    
    call magi#launch_magi_buffer('plan')
endfunction

" Send command to terminal after a delay
function! s:send_keys_to_terminal(job, keys, timer_id) abort
    call feedkeys("/" . a:keys, "n")
endfunction


" --- Chat functionality ---

" Opens the Magi chat interface
function! magi#chat() abort
    let g:magi_last_command = 'chat'
    
    let l:settings = s:load_config()
    if empty(l:settings)
        return
    endif
    
    let l:chat_cmd_config = get(get(get(l:settings, 'magi', {}), 'workflows', {}), 'chat', {})
    let l:chat_cmd = get(l:chat_cmd_config, 'cmd', 'cli/claude')

    if l:chat_cmd =~ '^cli/'
        call magi#launch_fullscreen_cli(substitute(l:chat_cmd, 'cli/', '', ''), 'Magi (claude)', 'chat')
    else
        echom "Unsupported chat command: " . l:chat_cmd
    endif
endfunction

" Reruns the last Magi command, or defaults to chat.
function! magi#rerun_last() abort
    if g:magi_last_command ==# 'plan'
        call magi#plan()
    else " Default to chat if empty or anything else
        call magi#chat()
    endif
endfunction


" Implementation for cli based chat
function! magi#launch_fullscreen_cli(command, tab_name, key) abort
    " Check if the Magi tab already exists and is valid
    let l:tab_id = s:get_magi_tab(a:key)
    if l:tab_id != -1
        execute 'tabnext ' . l:tab_id
        call feedkeys("i", "n")
        return
    endif

    if !executable(split(a:command)[0])
        echoerr "Magi: '" . a:command . "' executable not found in your PATH."
        return
    endif

    let l:current_tab = tabpagenr()
    call s:create_magi_tab(a:key)

    try
        let l:job = term_start(a:command, {
            \ 'curwin': 1,
            \ 'exit_cb': function('s:cleanup_terminal_tab', [a:key, bufnr('%')])
            \ })
    catch
        echoerr "Magi: Failed to launch terminal command: " . a:command
        tabclose
        return
    endtry

    " Set buffer variables for identification and navigation
    let b:is_magi_tab = 1
    let b:magi_key = a:key
    let b:magi_return_tab = l:current_tab
    
    " Set a friendly name for the tab/buffer
    " Check if buffer with this name already exists and delete it first
    let l:existing_buf = bufnr(a:tab_name)
    if l:existing_buf != -1 && l:existing_buf != bufnr('%')
        try
            execute 'bdelete! ' . l:existing_buf
        catch
            " Ignore
        endtry
    endif
    silent file `=a:tab_name`
    setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted

    " Mappings to switch back to code
    tnoremap <buffer> <silent> <C-s> <C-\><C-n>:call <SID>switch_to_return_tab()<CR>
    nnoremap <buffer> <silent> <C-s> :call <SID>switch_to_return_tab()<CR>

    echom "Magi: Started session in new tab. Press Ctrl-s to switch back to your code."

    return l:job
endfunction


" Launch magi buffer in separate tab or switch to it
function! magi#launch_magi_buffer(key) abort
    " Check if the Magi tab already exists and is valid
    let l:tab_id = s:get_magi_tab(a:key)
    if l:tab_id != -1
        execute 'tabnext ' . l:tab_id
        return
    endif
    
    let l:current_tab = tabpagenr()
    call s:create_magi_tab(a:key)
    
    " Set buffer variables for identification and navigation
    let b:is_magi_tab = 1
    let b:magi_key = a:key
    let b:magi_return_tab = l:current_tab
    
    " Set buffer properties
    setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
    
    " Set buffer name - check if buffer with this name already exists and delete it first
    let l:existing_buf = bufnr('MagiPlan')
    if l:existing_buf != -1 && l:existing_buf != bufnr('%')
        try
            execute 'bdelete! ' . l:existing_buf
        catch
            " Ignore
        endtry
    endif
    file MagiPlan
    
    " Insert initial content
    call setline(1, ' Write your instructions')
    call setline(2, '')
    call setline(3, ' <leader>x  prepare plan')
    call setline(4, ' <C-s>      go back to previous tab ')
    call setline(5, '-----------------------------------------------------------------')
    call setline(6, '')
    call setline(7, '')
    
    " Set filetype for syntax highlighting
    setlocal filetype=magi
    
    " Configure keybindings
    nnoremap <buffer> <C-s> :call <SID>switch_to_return_tab()<CR>
    inoremap <buffer> <C-s> <Esc>:call <SID>switch_to_return_tab()<CR>
    
    " Position cursor for editing
    normal! G
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
function! s:cleanup_terminal_tab(key, bufnr, job, exit_status) abort
    " Remove the key from the magi tabs registry
    if !empty(a:key) && has_key(g:magi_tabs, a:key)
        echom 'removing key: ' . a:key
        call remove(g:magi_tabs, a:key)
    endif

    " Clean up the buffer/tab if it still exists and is a magi tab
    " Find the tab that contains this buffer
    if getbufvar(a:bufnr, 'is_magi_tab', 0)
        for l:tabnr in range(1, tabpagenr('$'))
            let l:buflist = tabpagebuflist(l:tabnr)
            if index(l:buflist, a:bufnr) >= 0
                " Switch to the tab and close it
                execute 'tabnext ' . l:tabnr
                execute 'bdelete! ' . a:bufnr
                if tabpagenr('$') > 1
                    tabclose
                endif
                break
            endif
        endfor
    endif
endfunction

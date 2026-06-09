" Copyright (c) 2025 Augment
" MIT License - See LICENSE.md for full terms

" Handlers for autocommands and keybinds

" Check whether the server started. Errors to start should be reported in the
" Augment-log.
function! s:IsRunning() abort
    let client = augment#client#Client()
    return exists('client.client_id') || exists('client.job')
endfunction

let s:NOT_RUNNING_MSG = 'The Augment language server is not running. See ":Augment log" for more details.'

" Get the text of the current buffer, accounting for the newline at the end
function! s:GetBufText() abort
    return join(getline(1, '$'), "\n") . "\n"
endfunction

" Notify the server that a buffer has been opened
function! s:OpenBuffer() abort
    if !s:IsRunning()
        return
    endif

    let client = augment#client#Client()
    if has('nvim')
        call luaeval('require("augment").open_buffer(_A[1], _A[2])', [client.client_id, bufnr('%')])
    else
        let uri = 'file://' . expand('%:p')
        let text = s:GetBufText()
        call client.Notify('textDocument/didOpen', {
                    \ 'textDocument': {
                    \   'uri': uri,
                    \   'languageId': &filetype,
                    \   'version': b:changedtick,
                    \   'text': text,
                    \ },
                    \ })
    endif
endfunction

" Notify the server that a buffer has been updated
function! s:UpdateBuffer() abort
    if !s:IsRunning()
        return
    endif

    " The nvim lsp client does this automatically
    if !has('nvim')
        " Only send a change notification if the buffer has changed (as
        " tracked by b:changedtick)
        if exists('b:_augment_buf_tick') && b:_augment_buf_tick == b:changedtick
            return
        endif
        let b:_augment_buf_tick = b:changedtick

        let uri = 'file://' . expand('%:p')
        let text = s:GetBufText()
        call augment#client#Client().Notify('textDocument/didChange', {
                    \ 'textDocument': {
                    \   'uri': uri,
                    \   'version': b:changedtick,
                    \ },
                    \ 'contentChanges': [{'text': text}],
                    \ })
    endif
endfunction

" Request a completion from the server
function! s:RequestCompletion() abort
    if !s:IsRunning()
        return
    endif

    " Don't send a request if completions are disabled
    if exists('g:augment_disable_completions') && g:augment_disable_completions
        return
    endif

    " If there was a previous completion request with the same buffer version
    " (tracked by b:changedtick), don't send another
    if exists('b:_augment_comp_tick') && b:_augment_comp_tick == b:changedtick
        return
    endif
    let b:_augment_comp_tick = b:changedtick

    if has('nvim')
        " NOTE(mpauly): On neovim, we use the built-in lsp client which
        " requires the uri to be in the format defined by
        " vim.uri_from_fname(). There isn't a straightforward way to format
        " the uri on vim and it isn't causing any issues, so punting on it for
        " now.
        let uri = v:lua.vim.uri_from_fname(expand('%:p'))
    else
        let uri = 'file://' . expand('%:p')
    endif
    let text = join(getline(1, '$'), "\n")
    " TODO: remove version-- we use it elsewhere but it's not in the spec
    call augment#client#Client().Request('textDocument/completion', {
                \ 'textDocument': {
                \   'uri': uri,
                \   'version': b:changedtick,
                \ },
                \ 'position': {
                \   'line': line('.') - 1,
                \   'character': col('.') - 1,
                \ },
                \ })
endfunction

" Show the log
function! s:CommandLog(...) abort
    call augment#log#Show()
endfunction

" Send sign-in request to the language server
function! s:CommandSignIn(...) abort
    if !s:IsRunning()
        echohl WarningMsg
        echo s:NOT_RUNNING_MSG
        echohl None
        return
    endif

    call augment#client#Client().Request('augment/login', {})
endfunction

" Send sign-out request to the language server
function! s:CommandSignOut(...) abort
    if !s:IsRunning()
        echohl WarningMsg
        echo s:NOT_RUNNING_MSG
        echohl None
        return
    endif

    call augment#client#Client().Request('augment/logout', {})
endfunction

" NOTE: The enable/disable commands are deprecated
function! s:CommandEnable(...) abort
    call augment#DisplayError('The `Enable` and `Disable` commands are deprecated in favor of the `g:augment_disable_completions` option. See `:help g:augment_disable_completions` for more details.')
endfunction

function! s:CommandDisable(...) abort
    call augment#DisplayError('The `Enable` and `Disable` commands are deprecated in favor of the `g:augment_disable_completions` option. See `:help g:augment_disable_completions` for more details.')
endfunction

function! s:CommandStatus(...) abort
    if !exists('g:augment_initialized') || !g:augment_initialized
        call augment#DisplayError('The Augment plugin failed to initialize. See ":Augment log" for more details.')
        return
    endif

    if !s:IsRunning()
        echohl WarningMsg
        echo s:NOT_RUNNING_MSG
        echohl None
        return
    endif

    call augment#client#Client().Request('augment/status', {})
endfunction

function! s:CommandChat(range, args) abort
    if !s:IsRunning()
        echohl WarningMsg
        echo s:NOT_RUNNING_MSG
        echohl None
        return
    endif

    " If range arguments were provided (when using :Augment chat) or in visual
    " mode, get the selected text
    if a:range == 2 || mode() ==# 'v' || mode() ==# 'V'
        let selected_text = augment#chat#GetSelectedText()
    else
        let selected_text = ''
    endif

    let uri = augment#chat#GetUri()
    let history = augment#chat#GetHistory()

    " Use the message from the additional command arguments if provided, or
    " prompt the user for a message
    let message = empty(a:args) ? input('Message: ') : a:args

    " Handle cancellation or empty input. \_s matches whitespace including
    " newlines, so a message that is only blank lines is treated as cancel.
    if message ==# '' || message =~# '^\_s*$'
        redraw
        echo 'Chat cancelled'
        return
    endif

    call augment#chat#OpenChatPanel()
    call augment#chat#AppendMessage(message)

    call augment#log#Info(
                \ 'Making chat request with file=' . uri
                \ . ' selected_text="' . selected_text
                \ . '"' . ' message="' . message . '"')

    let params = {
        \ 'textDocumentPosition': {
        \     'textDocument': {
        \         'uri': uri,
        \     },
        \     'position': {
        \         'line': line('.') - 1,
        \         'character': col('.') - 1,
        \     },
        \ },
        \ 'message': message,
    \ }

    " Add selected text and history if available
    if !empty(selected_text)
        let params['selectedText'] = selected_text
    endif
    if !empty(history)
        let params['history'] = history
    endif

    call augment#client#Client().Request('augment/chat', params)
endfunction

" Open a floating window to compose a chat message before sending it. The
" floating input is Neovim-only; in Vim (and when a message is supplied
" directly) this falls back to the standard chat command, which prompts for a
" message via input() when none is given.
function! s:CommandChatInput(range, args) abort
    if !s:IsRunning()
        echohl WarningMsg
        echo s:NOT_RUNNING_MSG
        echohl None
        return
    endif

    " Determine whether a selection range is active. Leave visual mode so the
    " '< and '> marks are set for the chat flow to pick up on submit.
    let was_visual = index(['v', 'V', "\<C-v>"], mode()) >= 0
    if was_visual
        execute "normal! \<Esc>"
    endif
    let ranged = a:range == 2 || was_visual

    " A message passed directly on the command line skips the floating input.
    " Vim has no editable floating window, so it falls back to the input()
    " prompt provided by the standard chat command.
    if !empty(a:args) || !has('nvim')
        call s:CommandChat(ranged ? 2 : 0, a:args)
        return
    endif

    let source_win = win_getid()
    let Callback = function('s:ChatInputSubmit', [source_win, ranged])
    call augment#chat#OpenInputWindow(Callback)
endfunction

" Handle a message submitted from the floating chat input
function! s:ChatInputSubmit(source_win, ranged, message) abort
    " \_s matches whitespace including newlines, so a buffer of only blank
    " lines is treated as cancel rather than sending an empty message.
    if a:message ==# '' || a:message =~# '^\_s*$'
        redraw
        echo 'Chat cancelled'
        return
    endif

    " Restore focus to the window the input was opened from
    if win_id2win(a:source_win) != 0
        call win_gotoid(a:source_win)
    endif

    " Re-select the original range so it is passed through to the chat request,
    " mirroring the behavior of `:Augment chat` in visual mode. The '< and '>
    " marks were set when the command left visual mode, so `gv` works whether
    " invoked from visual mode or via an explicit `:'<,'>` range.
    if a:ranged
        normal! gv
    endif

    call s:CommandChat(a:ranged ? 2 : 0, a:message)
endfunction

function! s:CommandChatNew(range, args) abort
    call augment#chat#Reset()
endfunction

function! s:CommandChatToggle(range, args) abort
    call augment#chat#Toggle()
endfunction

" Help text for the available commands. The order of this list determines the
" order shown by `:Augment help`. Each entry has a usage string (shown in the
" detail header), a one-line summary (shown in the command list), and a list of
" detail lines (shown by `:Augment help <command>`).
let s:command_help = [
    \ {'name': 'status', 'usage': 'status', 'summary': 'View the current status of the plugin.', 'detail': [
    \     'View the current status of the plugin, including whether you are',
    \     'signed in and the syncing progress of any configured workspace folders.',
    \ ]},
    \ {'name': 'signin', 'usage': 'signin', 'summary': 'Sign in to Augment.', 'detail': [
    \     'Authenticate with the Augment service using OAuth. This is required',
    \     'before using the plugin for the first time.',
    \ ]},
    \ {'name': 'signout', 'usage': 'signout', 'summary': 'Sign out of Augment.', 'detail': [
    \     'Sign out of Augment.',
    \ ]},
    \ {'name': 'log', 'usage': 'log', 'summary': 'View the plugin log.', 'detail': [
    \     'View the plugin log. This is useful for debugging.',
    \ ]},
    \ {'name': 'chat', 'usage': 'chat [message]', 'summary': 'Send a chat message to Augment AI.', 'detail': [
    \     'Start a chat with Augment AI. In visual mode, the selected text will',
    \     'be included in the chat request. If no message is provided, you will',
    \     'be prompted to enter one.',
    \ ]},
    \ {'name': 'chat-input', 'usage': 'chat-input', 'summary': 'Compose a chat message in a floating window (Neovim only).', 'detail': [
    \     'Open a centered floating window with a markdown scratch buffer for',
    \     'composing a chat message before sending it. Submit with <C-s> or, in',
    \     'normal mode, <CR>; cancel with <Esc> or <C-c>. Like ":Augment chat" it',
    \     'is range-aware. Requires Neovim; in Vim it falls back to the input()',
    \     'prompt used by ":Augment chat".',
    \ ]},
    \ {'name': 'chat-new', 'usage': 'chat-new', 'summary': 'Start a new chat conversation.', 'detail': [
    \     'Start a new chat conversation with Augment AI, clearing the history',
    \     'from your context.',
    \ ]},
    \ {'name': 'chat-toggle', 'usage': 'chat-toggle', 'summary': 'Toggle the chat panel visibility.', 'detail': [
    \     'Open or close the chat conversation window. The conversation is',
    \     'preserved while the window is closed and can be reopened with the',
    \     'same command.',
    \ ]},
    \ {'name': 'help', 'usage': 'help [command]', 'summary': 'Show help for Augment commands.', 'detail': [
    \     'Show help for Augment commands. With no argument, list all available',
    \     'commands with a short description. With a command name, show detailed',
    \     'help for that command.',
    \ ]},
    \ {'name': 'enable', 'usage': 'enable', 'summary': '(deprecated) See g:augment_disable_completions.', 'detail': [
    \     'Deprecated. Use the g:augment_disable_completions option instead,',
    \     'which disables inline completions without affecting chat. See',
    \     '":help g:augment_disable_completions" for more details.',
    \ ]},
    \ {'name': 'disable', 'usage': 'disable', 'summary': '(deprecated) See g:augment_disable_completions.', 'detail': [
    \     'Deprecated. Use the g:augment_disable_completions option instead,',
    \     'which disables inline completions without affecting chat. See',
    \     '":help g:augment_disable_completions" for more details.',
    \ ]},
    \ ]

" Show help for the available commands. With no argument, list all commands;
" with a command name, show detailed help for that command.
function! s:CommandHelp(range, args) abort
    let topic = empty(a:args) ? '' : split(a:args)[0]

    if empty(topic)
        echohl Title
        echo 'Augment commands'
        echohl None
        for entry in s:command_help
            echo printf('  :Augment %-12s %s', entry.name, entry.summary)
        endfor
        echo 'Run ":Augment help <command>" for more details about a command.'
        return
    endif

    for entry in s:command_help
        " Note that ==? is case-insensitive comparison
        if topic ==? entry.name
            echohl Title
            echo ':Augment ' . entry.usage
            echohl None
            for line in entry.detail
                echo '    ' . line
            endfor
            return
        endif
    endfor

    echohl WarningMsg
    echo 'Augment: Unknown command: "' . topic . '". Run ":Augment help" to list available commands.'
    echohl None
endfunction

" Handle user commands
let s:command_handlers = {
    \ 'log': function('s:CommandLog'),
    \ 'signin': function('s:CommandSignIn'),
    \ 'signout': function('s:CommandSignOut'),
    \ 'enable': function('s:CommandEnable'),
    \ 'disable': function('s:CommandDisable'),
    \ 'status': function('s:CommandStatus'),
    \ 'chat': function('s:CommandChat'),
    \ 'chat-input': function('s:CommandChatInput'),
    \ 'chat-new': function('s:CommandChatNew'),
    \ 'chat-toggle': function('s:CommandChatToggle'),
    \ 'help': function('s:CommandHelp'),
    \ }

function! augment#Command(range, args) abort range
    if empty(a:args)
        call s:command_handlers['status']()
        return
    endif

    " If the plugin failed to initialize, only allow status, log, and help
    " commands
    let command = split(a:args)[0]
    if (!exists('g:augment_initialized') || !g:augment_initialized)
                \ && command !=# 'status' && command !=# 'log' && command !=# 'help'
        call augment#DisplayError('The Augment plugin failed to initialize. Only `:Augment status`, `:Augment log`, and `:Augment help` commands are available.')
        return
    endif

    for [name, Handler] in items(s:command_handlers)
        " Note that ==? is case-insensitive comparison
        if command ==? name
            " Call the command handler with the count of range arguments as
            " the first parameter, followed by the rest of the arguments to
            " the command as a single string
            let command_args = substitute(a:args, '^\S*\s*', '', '')
            call Handler(a:range, command_args)
            return
        endif
    endfor

    echohl WarningMsg
    echo 'Augment: Unknown command: "' . command . '"'
    echohl None
endfunction

function! augment#CommandComplete(ArgLead, CmdLine, CursorPos) abort
    return keys(s:command_handlers)->join("\n")
endfunction

" Autocommand handlers
function! augment#OnVimEnter() abort
    call augment#client#Client()
endfunction

function! augment#OnBufEnter() abort
    call s:OpenBuffer()
    call augment#chat#SaveUri()
endfunction

function! augment#OnTextChanged() abort
    call s:UpdateBuffer()
endfunction

function! augment#OnTextChangedI() abort
    " Since CursorMovedI is always called before TextChangedI, the suggestion will already be cleared
    call s:UpdateBuffer()
    call s:RequestCompletion()
endfunction

function! augment#OnCursorMovedI() abort
    call augment#suggestion#Clear()
endfunction

function! augment#OnInsertEnter() abort
    call s:UpdateBuffer()
    call s:RequestCompletion()
endfunction

function! augment#OnInsertLeavePre() abort
    call augment#suggestion#Clear()
endfunction

" Accept the currently active suggestion if one is available, otherwise insert
" the fallback text provided as the first argument
function! augment#Accept(...) abort
    " If no fallback was provided, don't add any text
    let fallback = a:0 >= 1 ? a:1 : ''

    if !augment#suggestion#Accept()
        call feedkeys(fallback, 'nt')
    endif
endfunction

" Display an error message to the user in addition to logging it
function! augment#DisplayError(message) abort
    " If we have already entered the editor, display the error message
    " immediately. Otherwise, wait for VimEnter.
    if v:vim_did_enter
        echohl ErrorMsg | echom 'Augment: ' . a:message | echohl None
    else
        " Shadow the message argument with a script-local variable. This means
        " that subsequent calls will override the previous message, which
        " should be fine for our use case.
        let s:error_message = a:message
        augroup augment_error
            autocmd!
            autocmd VimEnter * echohl ErrorMsg | echom 'Augment: ' . s:error_message | echohl None
        augroup END
    endif
    call augment#log#Error(a:message)
endfunction

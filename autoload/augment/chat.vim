" Copyright (c) 2025 Augment
" MIT License - See LICENSE.md for full terms

" Utilities for chat

function! s:ResetChatContents() abort
    let chat_buf = bufnr('AugmentChatHistory')
    if chat_buf == -1
        call augment#log#Error('Chat reset failed: Could not find chat history buffer')
        return
    endif

    call setbufvar(chat_buf, '&modifiable', v:true)
    silent call deletebufline(chat_buf, 1, '$')
    call augment#chat#AppendText('# Augment Chat History'
                \ . "\n\n"
                \ . '`:Augment chat`         Send a chat message in the current conversation'
                \ . "\n"
                \ . '`:Augment chat-new`     Start a new conversation'
                \ . "\n"
                \ . '`:Augment chat-toggle`  Toggle the chat panel visibility'
                \ . "\n\n")
endfunction

function! augment#chat#Toggle() abort
    let chat_id = bufwinid('AugmentChatHistory')
    if chat_id == -1
        call augment#chat#OpenChatPanel()
    else
        " Don't close if it's the last window
        if winnr('$') > 1
            call win_execute(chat_id, 'close')
        endif
    endif
endfunction

function! augment#chat#OpenChatPanel() abort
    let current_win = win_getid()

    " Check if the panel already exists and has been setup
    if bufexists('AugmentChatHistory') && !getbufvar('AugmentChatHistory', '&modifiable')
        if bufwinid('AugmentChatHistory') == -1
            botright 80vnew AugmentChatHistory
        endif
        call win_gotoid(current_win)
        return
    endif

    " Open a buffer for the chat history with a width of 80 characters
    botright 80vnew AugmentChatHistory
    setlocal buftype=nofile      " Buffer will never be written to a file
    setlocal nomodifiable        " Prevent any modifications
    setlocal noswapfile          " Don't create a swapfile
    " NOTE(mpauly): winfixbuf is not available in some subversions of vim 9.1
    if exists('&winfixbuf')
        setlocal winfixbuf       " Keep buffer in window when splitting
    endif
    setlocal bufhidden=hide      " When buffer is abandoned, hide it
    setlocal nobuflisted         " Hide from :ls
    setlocal wrap                " Wrap long lines
    setlocal linebreak           " Wrap at word boundaries
    setlocal filetype=markdown   " Use markdown syntax highlighting
    setlocal nonumber            " Hide line numbers
    setlocal norelativenumber    " Hide relative line numbers
    setlocal signcolumn=no       " Hide sign column
    setlocal nocursorline        " Disable cursor line highlighting
    setlocal nospell             " Disable spell checking
    setlocal nofoldenable        " Disable folding
    setlocal textwidth=0         " Disable text width limit
    setlocal scrolloff=0         " Disable scrolloff

    " Add the chat header to the buffer
    call s:ResetChatContents()

    " TODO(AU-6480): create another buffer for the chat input
    " new AugmentChatInput

    call win_gotoid(current_win)
endfunction

function! augment#chat#Reset() abort
    call s:ResetChatContents()
    call s:ResetHistory()
endfunction

function! s:ResetHistory() abort
    let g:_augment_chat_history = []
endfunction

function! augment#chat#AppendText(text) abort
    let chat_buf = bufnr('AugmentChatHistory')
    if chat_buf == -1
        call augment#log#Error('Chat append failed: Could not find chat history buffer')
        return
    endif

    let lines = split(a:text, "\n", v:true)
    let last_line = getbufline(chat_buf, '$')[0]

    call setbufvar(chat_buf, '&modifiable', v:true)
    call setbufline(chat_buf, '$', last_line . lines[0])
    call appendbufline(chat_buf, '$', lines[1:])
    call setbufvar(chat_buf, '&modifiable', v:false)
endfunction

function! augment#chat#AppendMessage(message) abort
    " If not the first message, scroll to the bottom
    let chat_id = bufwinid('AugmentChatHistory')
    if !empty(augment#chat#GetHistory()) && chat_id != -1
        let command = "call winrestview({'lnum': line('$'), 'topline': line('$')})"
        call win_execute(chat_id, command)
    endif

    let message_text = '================================================================================'
                \ . "\n\n"
                \ . "\t*You*"
                \ . "\n\n"
                \ . a:message
                \ . "\n\n"
                \ . '--------------------------------------------------------------------------------'
                \ . "\n\n"
                \ . "\t*Augment*"
                \ . "\n\n"
    call augment#chat#AppendText(message_text)
endfunction

function! augment#chat#AppendHistory(request_message, response_text, request_id) abort
    if !exists('g:_augment_chat_history')
        let g:_augment_chat_history = []
    endif
    call add(g:_augment_chat_history, {
        \ 'request_message': a:request_message,
        \ 'response_text': a:response_text,
        \ 'request_id': a:request_id,
        \ })
endfunction

function! augment#chat#GetHistory() abort
    if exists('g:_augment_chat_history')
        return g:_augment_chat_history
    endif
    return []
endfunction

function! augment#chat#SaveUri() abort
    if bufname('%') !=# 'AugmentChatHistory'
        let g:_augment_current_uri = 'file://' . expand('%:p')
    endif
endfunction

function! augment#chat#GetUri() abort
    if exists('g:_augment_current_uri')
        return g:_augment_current_uri
    endif
    return 'file://' . expand('%:p')
endfunction

function! s:GetBufSelection(line_start, col_start, line_end, col_end) abort
    if a:line_start == a:line_end
        return getline(a:line_start)[a:col_start - 1:a:col_end - 1]
    endif

    let lines = []
    call add(lines, getline(a:line_start)[a:col_start - 1:])
    call extend(lines, getline(a:line_start + 1, a:line_end - 1))
    call add(lines, getline(a:line_end)[0:a:col_end - 1])
    return join(lines, "\n")
endfunction

function! augment#chat#GetSelectedText() abort
    " If in visual mode use the current selection
    if mode() ==# 'v' || mode() ==# 'V'
        let [line_one, col_one] = getpos('.')[1:2]
        let [line_two, col_two] = getpos('v')[1:2]

        " . may be before or after v, so need to do some sorting
        if line_one < line_two
            let line_start = line_one
            let col_start = col_one
            let line_end = line_two
            let col_end = col_two
        elseif line_one > line_two
            let line_start = line_two
            let col_start = col_two
            let line_end = line_one
            let col_end = col_one
        else
            " If the lines are the same, the columns may be different
            let line_start = line_one
            let line_end = line_two
            if col_one <= col_two
                let col_start = col_one
                let col_end = col_two
            else
                let col_start = col_two
                let col_end = col_one
            endif
        endif

        " . and v return column positions one lower than '< and '>
        let col_start += 1
        let col_end += 1

        " In visual line mode, the columns will be incorrect
        if mode() ==# 'V'
            let col_start = 1
            let col_end = v:maxcol
        endif

        return s:GetBufSelection(line_start, col_start, line_end, col_end)
    endif

    " Otherwise, assume '< and '> are populated with the correct selection
    let [line_start, col_start] = getpos("'<")[1:2]
    let [line_end, col_end] = getpos("'>")[1:2]
    return s:GetBufSelection(line_start, col_start, line_end, col_end)
endfunction

function! augment#chat#ApplyCodeBlocks() abort
    let history = augment#chat#GetHistory()
    if empty(history)
        call augment#log#Error('No chat history found')
        return
    endif

    " Iterate through all messages in history
    for msg in history
        let response = msg.response_text
        let lines = split(response, "\n")
        let in_block = 0
        let current_block = {'path': '', 'content': []}
        
        for line in lines
            " Check for code block start with path
            let block_start = matchlist(line, '```\([^[:space:]]\+\)\s\+\(.\+\)$')
            if !empty(block_start)
                let in_block = 1
                let current_block.path = block_start[2]
                let current_block.content = []
                continue
            endif

            " Check for code block end
            if line =~# '^```$'
                if in_block && !empty(current_block.path)
                    " Apply the changes
                    call s:ApplyCodeBlock(current_block)
                endif
                let in_block = 0
                let current_block = {'path': '', 'content': []}
                continue
            endif

            " Collect content lines
            if in_block
                call add(current_block.content, line)
            endif
        endfor
    endfor
endfunction

function! s:ApplyCodeBlock(block) abort
    " Ensure the directory exists
    let dir = fnamemodify(a:block.path, ':h')
    if !isdirectory(dir)
        call mkdir(dir, 'p')
    endif

    " Create or overwrite the file
    call writefile(a:block.content, a:block.path)

    " Log success
    call augment#log#Info('Applied changes to: ' . a:block.path)
endfunction

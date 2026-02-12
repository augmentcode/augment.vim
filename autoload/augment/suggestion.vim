" Copyright (c) 2025 Augment
" MIT License - See LICENSE.md for full terms

" Functions for interacting with augment suggestions

" Remove ghost text visual elements without touching suggestion state
function! augment#suggestion#ClearGhostText() abort
    if has('nvim')
        let ns_id = nvim_create_namespace('AugmentSuggestion')
        call nvim_buf_clear_namespace(0, ns_id, 0, -1)
    else
        call prop_remove({'type': 'AugmentSuggestion', 'all': v:true})
    endif
endfunction

" Clear the suggestion
function! augment#suggestion#Clear(...) abort
    call augment#suggestion#ClearGhostText()

    let current = exists('b:_augment_suggestion') ? b:_augment_suggestion : {}
    let b:_augment_suggestion = {}

    " Send the reject resolution, checking optional argument to skip
    let skip_resolution = a:0 > 0 ? a:1 : v:false
    if !empty(current) && !skip_resolution
        call augment#client#Client().Notify('augment/resolveCompletion', {
                    \ 'requestId': current.request_id,
                    \ 'accept': v:false,
                    \ })
        call augment#log#Debug('Rejected completion with request_id=' . current.request_id . ' text=' . string(current.lines))
    endif

    return current
endfunction

" Render ghost text for the given lines at the current cursor position
function! augment#suggestion#Render(lines) abort
    if empty(a:lines)
        return
    endif

    " Text properties don't render tabs, so manually add the correct spacing
    let tab_spaces = repeat(' ', &tabstop)
    let lines = mapnew(a:lines, {_, v -> substitute(v, "\t", tab_spaces, 'g')})

    " Show the suggestion in ghost text
    if has('nvim')
        let ns_id = nvim_create_namespace('AugmentSuggestion')

        let virt_text = [[lines[0], 'AugmentSuggestionHighlight']]
        let virt_lines = mapnew(lines[1:], {_, val -> [[val, 'AugmentSuggestionHighlight']]})
        let opts = {
                    \ 'virt_text_pos': 'inline',
                    \ 'virt_text': virt_text,
                    \ 'virt_lines': virt_lines,
                    \ }

        call nvim_buf_set_extmark(0, ns_id, line('.') - 1, col('.') - 1, opts)
    else
        call prop_add(line('.'), col('.'), {
                    \ 'type': 'AugmentSuggestion',
                    \ 'text': lines[0],
                    \ })

        for line in lines[1:]
            " Since vim won't display a text prop line that's empty, add a space
            let line_text = line != '' ? line : ' '
            call prop_add(line('.'), 0, {
                        \ 'type': 'AugmentSuggestion',
                        \ 'text_align': 'below',
                        \ 'text': line_text,
                        \ })
        endfor
    endif
endfunction

" Show a suggestion
function! augment#suggestion#Show(text, request_id, req_line, req_col, req_changedtick) abort
    if len(a:text) == 0
        return
    endif

    call augment#suggestion#Clear()

    " Save the suggestion information in a buffer-local variable
    let b:_augment_suggestion = {
                \ 'lines': split(a:text, "\n", 1),
                \ 'request_id': a:request_id,
                \ 'req_line': a:req_line,
                \ 'req_col': a:req_col,
                \ 'req_changedtick': a:req_changedtick,
                \ }

    call augment#suggestion#Render(b:_augment_suggestion.lines)
endfunction

" Compute remaining suggestion lines after accepting a word.
function! s:ComputeRemainingLines(first_line, word, lines) abort
    let remaining_first_line = strpart(a:first_line, len(a:word))
    if !empty(remaining_first_line)
        return [remaining_first_line] + a:lines[1:]
    endif
    if len(a:lines) > 1
        return a:lines[1:]
    endif
    return []
endfunction

" Extract the next word from the suggestion lines.
" Returns [word, first_line] on success, or empty list if nothing to extract.
" word='' means consume a newline boundary.
function! s:ExtractNextWord(lines) abort
    if empty(a:lines)
        return []
    endif

    " Newline boundary: first line empty but more lines follow
    if empty(a:lines[0]) && len(a:lines) > 1
        return ['', '']
    endif

    if empty(a:lines[0])
        return []
    endif

    let first_line = a:lines[0]
    let first_char = first_line[0]

    if first_char =~ '\s'
        let word = matchstr(first_line, '^\s\+')
    elseif first_char =~ '\k'
        let word = matchstr(first_line, '^\k\+')
    else
        let word = matchstr(first_line, '^\%(\k\@!\S\)\+')
    endif

    if empty(word)
        return []
    endif

    return [word, first_line]
endfunction

" Accept the next word of the currently active suggestion, returning true
" if there was a word to accept and false otherwise
function! augment#suggestion#AcceptWord() abort
    " Get current suggestion without clearing it
    if !exists('b:_augment_suggestion') || empty(b:_augment_suggestion)
        return v:false
    endif
    let info = b:_augment_suggestion

    " Check buffer state is as expected
    if line('.') != info.req_line || col('.') != info.req_col || b:changedtick != info.req_changedtick
        let buf_state = '{line=' . line('.') . ', col=' . col('.') . ', changedtick=' . b:changedtick . '}'
        let buf_expected = '{line=' . info.req_line . ', col=' . info.req_col . ', changedtick=' . info.req_changedtick . '}'
        call augment#log#Warn(
                    \ 'Attempted to accept word from completion "' . string(info.lines)
                    \ . '" with buffer state ' . buf_state
                    \ . ' and expected ' . buf_expected
                    \ )
        return v:false
    endif

    if empty(info.lines)
        return v:false
    endif

    let extracted = s:ExtractNextWord(info.lines)
    if empty(extracted)
        return v:false
    endif
    let [word, first_line] = extracted

    " Set the skip_clear flag to prevent autocommands from interfering
    let b:_augment_suggestion_skip_clear = v:true
    let l:bufnr = bufnr('%')

    try
        if empty(word)
            " Empty word means we're consuming a newline boundary: split the
            " current line at the cursor and move to the new line
            let before = strpart(getline(line('.')), 0, col('.') - 1)
            let after = strpart(getline(line('.')), col('.') - 1)
            call setline(line('.'), before)
            call append(line('.'), after)
            call cursor(line('.') + 1, 1)
            let remaining_lines = info.lines[1:]
        else
            " Insert the word into the buffer
            let before = strpart(getline(line('.')), 0, col('.') - 1)
            let after = strpart(getline(line('.')), col('.') - 1)
            call setline(line('.'), before . word . after)

            " Move cursor to the end of the inserted word
            call cursor(line('.'), col('.') + len(word))

            let remaining_lines = s:ComputeRemainingLines(first_line, word, info.lines)
        endif

        " Clear the old ghost text and update with remaining suggestion
        call augment#suggestion#ClearGhostText()

        " Update the suggestion state BEFORE unsetting skip flag
        if !empty(remaining_lines)
            let b:_augment_suggestion = {
                        \ 'lines': remaining_lines,
                        \ 'request_id': info.request_id,
                        \ 'req_line': line('.'),
                        \ 'req_col': col('.'),
                        \ 'req_changedtick': b:changedtick,
                        \ }
            " Render the remaining ghost text
            call augment#suggestion#Render(remaining_lines)

            call augment#log#Debug('AcceptWord: Updated suggestion state - remaining=' . string(remaining_lines) . ' req_line=' . line('.') . ' req_col=' . col('.') . ' req_changedtick=' . b:changedtick)
        else
            " No remaining suggestion, clear state and send accept resolution
            let b:_augment_suggestion = {}
            call augment#client#Client().Notify('augment/resolveCompletion', {
                        \ 'requestId': info.request_id,
                        \ 'accept': v:true,
                        \ })
            call augment#log#Debug('Accepted completion (via AcceptWord) with request_id=' . info.request_id . ' text=' . string(info.lines))
        endif
    finally
        " Unset the skip_clear flag after a short delay to allow autocommands to settle
        if exists('b:_augment_suggestion_skip_clear_timer')
            call timer_stop(b:_augment_suggestion_skip_clear_timer)
        endif
        let b:_augment_suggestion_skip_clear_timer = timer_start(10, {-> setbufvar(l:bufnr, '_augment_suggestion_skip_clear', v:false)})
    endtry

    return v:true
endfunction

" Accept the currently active suggestion if one is available, returning true
" if there was a suggestion to accept and false otherwise
function! augment#suggestion#Accept() abort
    let info = augment#suggestion#Clear(v:true)
    if !has_key(info, 'lines')
        return v:false
    endif
    let lines = info.lines

    " Check buffer state is as expected
    if line('.') != info.req_line || col('.') != info.req_col || b:changedtick != info.req_changedtick
        let buf_state = '{line=' . line('.') . ', col=' . col('.') . ', changedtick=' . b:changedtick . '}'
        let buf_expected = '{line=' . info.req_line . ', col=' . info.req_col . ', changedtick=' . info.req_changedtick . '}'
        call augment#log#Warn(
                    \ 'Attempted to accept completion "' . string(lines)
                    \ . '" with buffer state ' . buf_state
                    \ . ' and expected ' . buf_expected
                    \ )
        return v:false
    endif

    if empty(lines)
        return v:false
    endif

    " Add the first line of the suggestion
    let before = strpart(getline(line('.')), 0, col('.') - 1)
    let after = strpart(getline(line('.')), col('.') - 1)
    call setline(line('.'), before . lines[0] . after)

    " Add the rest of the suggestion
    for i in range(len(lines) - 1, 1, -1)
        call append(line('.'), lines[i])
    endfor

    " Put the cursor at the end of the accepted text
    if len(lines) == 1
        call cursor(line('.'), col('.') + len(lines[0]))
    else
        call cursor(line('.') + len(lines) - 1, len(lines[-1]) + 1)
    endif

    " Send the accept resolution
    call augment#client#Client().Notify('augment/resolveCompletion', {
                \ 'requestId': info.request_id,
                \ 'accept': v:true,
                \ })
    call augment#log#Debug('Accepted completion with request_id=' . info.request_id . ' text=' . string(lines))

    return v:true
endfunction

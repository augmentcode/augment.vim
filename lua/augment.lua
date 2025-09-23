-- Copyright (c) 2025 Augment
-- MIT License - See LICENSE.md for full terms

local M = {}

-- Start the lsp client
M.start_client = function(command, notification_methods, workspace_folders)
    local vim_version = tostring(vim.version())
    local plugin_version = vim.call('augment#version#Version')

    -- Set up noficiation handlers that forward requests to the handlers in the vimscript
    local handlers = {}
    for _, method in ipairs(notification_methods) do
        handlers[method] = function(_, params, _)
            vim.call('augment#client#NvimNotification', method, params)
        end
    end

    local config = {
        name = 'Augment Server',
        cmd = command,
        init_options = {
            editor = 'nvim',
            vimVersion = vim_version,
            pluginVersion = plugin_version,
        },
        on_exit = function(code, signal, client_id)
            -- We can not call vim functions directly from callback functions.
            -- Instead, we schedule the functions for async execution
            vim.schedule(function()
                vim.call('augment#client#NvimOnExit', code, signal, client_id)
            end)
        end,
        handlers = handlers,
        -- TODO(mpauly): on_error
    }

    -- If workspace folders are provided, use them
    if workspace_folders and #workspace_folders > 0 then
        config.workspace_folders = workspace_folders
    end

    local id = vim.lsp.start(config)
    return id
end

-- Attach the lsp client to a buffer
M.open_buffer = function(client_id, bufnr)
    vim.lsp.buf_attach_client(bufnr, client_id)
end

-- Send a lsp notification
M.notify = function(client_id, method, params)
    local client = vim.lsp.get_client_by_id(client_id)
    if not client then
        vim.call('augment#log#Error', 'No lsp client found for id: ' .. client_id)
        return
    end

    client:notify(method, params)
end

-- Send a lsp request
M.request = function(client_id, method, params)
    local client = vim.lsp.get_client_by_id(client_id)
    if not client then
        vim.call('augment#log#Error', 'No lsp client found for id: ' .. client_id)
        return
    end

    local _, id = client:request(method, params, function(err, result)
        vim.call('augment#client#NvimResponse', method, params, result, err)
    end)
    return id
end

return M

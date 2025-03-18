# Augment Vim & Neovim Plugin

## A Quick Tour

Augment's Vim/Neovim plugin provides inline code completions and multi-turn
chat conversations specially tailored to your codebase. The plugin is designed
to work with any modern Vim or Neovim setup, and features the same underlying
context engine that powers our VSCode and IntelliJ plugins.

Once you've installed the plugin, tell Augment about your project by adding
[workspace folders](#workspace-folders) to your config file, and then sign-in
to the Augment service. You can now open a source file in your project, begin
typing, and you should receive context-aware code completions. Use tab to
accept a suggestion, or keep typing to refine the suggestions. To ask questions
about your codebase or request specific changes, use the `:Augment chat` command
to start a chat conversation.

## Getting Started

1. Sign up for a free trial of Augment at
   [augmentcode.com](https://augmentcode.com).

1. Ensure you have a compatible editor version installed. Both Vim and Neovim
   are supported, but the plugin may require a newer version than what is
   installed on your system by default.

   - For [Vim](https://github.com/vim/vim?tab=readme-ov-file#installation),
     version 9.1.0 or newer.

   - For
     [Neovim](https://github.com/neovim/neovim/tree/master?tab=readme-ov-file#install-from-package),
     version 0.10.0 or newer.

1. Install [Node.js](https://nodejs.org/en/download/package-manager/all),
   version 22.0.0 or newer, which is a required dependency.

1. Install the plugin

    - Manual installation (Vim):

        ```bash
        git clone https://github.com/augmentcode/augment.vim.git \
            ~/.vim/pack/augment/start/augment.vim
        ```

    - Manual installation (Neovim):

        ```bash
        git clone https://github.com/augmentcode/augment.vim.git \
            ~/.config/nvim/pack/augment/start/augment.vim
        ```

    - Vim Plug:

        ```vim
        Plug 'augmentcode/augment.vim'
        ```

    - Lazy.nvim:

        ```lua
        { 'augmentcode/augment.vim' },
        ```

1. Add workspace folders to your config file. This is really essential to getting the most out of augment! See the [Workspace Folders](#workspace-folders) section for more information.

1. Open Vim and sign in to Augment with the `:Augment signin` command.

## Basic Usage

Open a file in vim, start typing, and use tab to accept suggestions as they
appear.

The following commands are provided:

```vim
:Augment status        " View the current status of the plugin
:Augment signin        " Start the sign in flow
:Augment signout       " Sign out of Augment
:Augment log           " View the plugin log
:Augment chat          " Send a chat message to Augment AI
:Augment chat-new      " Start a new chat conversation
:Augment chat-toggle   " Toggle the chat panel visibility
```

## Workspace Folders

Workspace folders help Augment understand your codebase better by providing
additional context. Adding your project's root directory as a workspace folder
allows Augment to take advantage of context from across your project, rather
than just the currently open file, improving the accuracy and style of
completions and chat.

You can configure workspace folders by setting
`g:augment_workspace_folders` in your vimrc:

```vim
let g:augment_workspace_folders = ['/path/to/project', '~/another-project']
```

Workspace folders can be specified using absolute paths or paths relative to
your home directory (~). Adding your project's root directory as a workspace
folder helps Augment generate completions that match your codebase's patterns
and conventions.

Note: This option must be set before the plugin is loaded.

After adding a workspace folder and restarting vim, the output of the
`:Augment status` command will include the syncing progress for the added
folder.

If you want to ignore particular files or directories from your workspace, you
can create a `.augmentignore` file in the root of your workspace folder. This
file is treated similar to a `.gitignore` file. For example, to ignore all
files within the `node_modules` directory, you can add
the following lines to your `.augmentignore` file:

```
node_modules/
```

For more information on how to use the `.augmentignore` file, see the [documentation](https://docs.augmentcode.com/setup-augment/sync).


## Chat

Augment chat supports multi-turn conversations using your project's full
context. Once a conversation is started, subsequent chat exchanges will include
the history from the previous exchanges. This is useful for asking follow-up
questions or getting context-specific help.

You can interact with chat in two ways:

1. Direct command with message:

    ```vim
    :Augment chat How do I implement binary search?
    ```

2. With selected text:

   - Select text in visual mode

   - Type `:Augment chat` followed by your question about the selection

The response will appear in a separate chat buffer with markdown formatting.

To start a new conversation, use the `:Augment chat-new` command. This will
clear the chat history from your context.

Use the `:Augment chat-toggle` command to open and close the chat panel. When
the chat panel is closed, the chat conversation will be preserved and can be
reopened with the same command.

## Alternate Keybinds

By default, tab is used to accept a suggestion. If you want to use a
different key, create a mapping that calls `augment#Accept()`. The function
takes an optional argument used to specify the fallback text to insert if no
suggestion is available.

```vim
" Use Ctrl-Y to accept a suggestion
inoremap <c-y> <cmd>call augment#Accept()<cr>

" Use enter to accept a suggestion, falling back to a newline if no suggestion
" is available
inoremap <cr> <cmd>call augment#Accept("\n")<cr>
```

or in neovim
```lua
-- Use Ctrl-Y to accept a suggestion
vim.keymap.set('i', '<C-Y>', '<cmd>call augment#Accept()<CR>', { noremap = true })

-- Use enter to accept a suggestion, falling back to a newline if no suggestion is available
vim.keymap.set('i', '<cr>', '<cmd>call augment#Accept()<CR>', { noremap = true })
```

The default tab mapping can be disabled by setting
`g:augment_disable_tab_mapping = v:true` before the plugin is loaded.

Completions can be disabled entirely by setting
`g:augment_disable_completions = v:true` in your vimrc or at any time during
editing.

If another plugin uses tab in insert mode, the Augment tab mapping may be
overridden depending on the order in which the plugins are loaded. If tab isn't
working for you, the `imap <tab>` command can be used to check if the mapping is
present.

## FAQ

**Q: I'm not seeing any completions. Is the plugin working?**

A: You may want to first check the output of the `:Augment status` command.
This command will show the current status of the plugin, including whether
you're signed in and whether your workspace folders are synced. If you're not
signed in, you'll need to sign in using the `:Augment signin` command. If those
are not indicating a problem, you can check the plugin log using the `:Augment
log` command. This will show any errors that may have occurred.

**Q: Can I create shortcuts for the Augment commands?**

A: Absolutely! You can create mappings for any of the Augment commands. For
example, to create a shortcut for the `:Augment chat*` commands, you can add the
following to your vimrc:

```vim
nnoremap <leader>ac :Augment chat<CR>
vnoremap <leader>ac :Augment chat<CR>
nnoremap <leader>an :Augment chat-new<CR>
nnoremap <leader>at :Augment chat-toggle<CR>
```

**Q: My workspace is taking a long time to sync. What should I do?**

A: It may take a while to sync if you have a very large codebase that has not
been synced before. It's also not uncommon to inadvertenly include a large
directory like `node_modules/`. You can use `:Augment status` to see the
progress of the sync. If the sync is making progress but just slow, it may be
worth checking if you have a large directory that you don't need to sync. You
can add these directories to your `.augmentignore` file to exclude it from the
sync. If you're still having trouble, please file a github issue with a
description of the problem and include the output of `:Augment log`.


## Licensing and Distribution

This repository includes two main components:

1. **Vim Plugin:** This includes all files in the repository except `dist` folder. These files are licensed under the [MIT License](LICENSE.md#vim-plugin).
2. **Server (`dist` folder):** This file is proprietary and licensed under a [Custom Proprietary License](LICENSE.md#server).

For details on usage restrictions, refer to the [LICENSE.md](LICENSE.md) file.

## Reporting Issues

We encourage users to report any bugs or issues directly to us. Please use the [Issues](https://github.com/augmentcode/augment.vim/issues) section of this repository to share your feedback.

For any other questions, feel free to reach out to support@augmentcode.com.

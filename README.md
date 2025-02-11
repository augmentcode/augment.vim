# Augment Vim & Neovim Plugin

> [!WARNING]
> This plugin is in early alpha development stage. Features may be incomplete,
> unstable, or change without notice. While basic functionality is available,
> you may encounter bugs, performance issues, or unexpected behavior. Current
> platform support is limited to MacOS and Linux, with Windows to be added at a
> later date.

## Installation

1. Both Vim and Neovim are supported, but the plugin may require a newer version
   than what's installed on your system by default.

   - [Vim](https://github.com/vim/vim?tab=readme-ov-file#installation) version 9.1.0 or newer.

   - [Neovim](https://github.com/neovim/neovim/tree/master?tab=readme-ov-file#install-from-package), version
     0.10.0 or newer.

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

1. Open Vim and sign in to Augment with the `:Augment signin` command.

## Basic Usage

Open a file in vim, start typing, and use tab to accept suggestions as they
appear.

The following commands are provided:

```vim
:Augment status        " View the current status of the plugin
:Augment signin        " Start the sign in flow
:Augment signout       " Sign out of Augment
:Augment enable        " Globally enable suggestions (on by default)
:Augment disable       " Globally disable suggestions
:Augment log           " View the plugin log
:Augment chat          " Send a chat message to Augment AI
:Augment chat-new      " Start a new chat conversation
:Augment chat-toggle   " Toggle the chat panel visibility
```

## Chat

The chat command allows you to interact with Augment AI in a conversational
manner. You can use it in two ways:

1. Direct command with message:

    ```vim
    :Augment chat How do I implement binary search?
    ```

2. With selected text:

   - Select text in visual mode

   - Type `:Augment chat` followed by your question about the selection

The response will appear in a new buffer with markdown formatting. Note that
chat is currently limited to single-turn conversations - each chat command
starts a new conversation.

## Workspace Folders

Workspace folders help Augment understand your codebase better by providing
additional context. You can configure workspace folders by setting
`g:augment_workspace_folders` in your vimrc:

```vim
let g:augment_workspace_folders = ['/path/to/project', '~/another-project']
```

Workspace folders can be specified using absolute paths or paths relative to
your home directory (~). Adding your project's root directory as a workspace
folder helps Augment generate completions that match your codebase's patterns
and conventions.

Note: This option must be set before the plugin is loaded.

## Alternate Keybinds

By default, tab is used to accept a suggestion. If you want to use a
different key, create a mapping that calls `augment#Accept()`. The function
takes an optional arugment used to specify the fallback text to insert if no
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

If another plugin uses tab in insert mode, the Augment tab mapping may be
overridden depending on the order in which the plugins are loaded. If tab isn't
working for you, the `imap <tab>` command can be used to check if the mapping is
present.

## Licensing and Distribution

This repository includes two main components:

1. **Vim Plugin:** This includes all files in the repository except `dist` folder. These files are licensed under the [MIT License](LICENSE.md#vim-plugin).
2. **Server (`dist` folder):** This file is proprietary and licensed under a [Custom Proprietary License](LICENSE.md#server).

For details on usage restrictions, refer to the [LICENSE.md](LICENSE.md) file.

## Reporting Issues

We encourage users to report any bugs or issues directly to us. Please use the [Issues](https://github.com/augmentcode/augment.vim/issues) section of this repository to share your feedback.

For any other questions, feel free to reach out to support@augmentcode.com.

# Augment Vim Plugin Changelog

This file documents the notable changes for each stable version of the Augment
Vim plugin. The following list is not necessarily comprehensive, but should
include any changes that may impact the user experience.

## Unreleased

- Add the `:Augment chat-input` command, which opens a floating window for
  composing a chat message before sending it (Neovim only). It is range-aware
  like `:Augment chat`, and falls back to the standard `input()` prompt on Vim.

## 0.25.1

- Deprecate the `Enable` and `Disable` commands in favor of the
  `g:augment_disable_completions` option which disables inline completions but
  not the chat feature. See `:help g:augment_disable_completions` for more
  details.
- Check for the `winfixbuf` option before setting it to avoid an error on older
  versions of Vim.
- Perform a runtime compatibility check on startup to warn users if they are
  running an unsupported version of Node.js.
- Improve the auth flow by significantly shortening the auth URL (addressing
  issues with truncated URLs) and improving the error messages on failure.
- Add support for filepaths containing spaces.

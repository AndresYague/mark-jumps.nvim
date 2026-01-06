# mark-jumps.nvim

## Description

Small-sized plugin that makes it easy to place and go to marks accross your
files. Although it uses vim's global marks (i.e. they work across files), it
tries to segregate the marks by project.

## Usage

Place a mark in the current buffer with

```lua
require('mark-jumps').mark_add()
```

Navigate away and return to the file exactly where you left off with
`<prefix>1` without having to nagivate the jump-list with `<C-O>`, where
`<prefix>` is set up in the [Configuration](#configuration) below. Place as
many marks as `mark_names` are set-up and nagivate to them with `<prefix>N`
where `N` is the place of the mark in the list. Alternatively, open a picker
with

```lua
require('mark-jumps').choose_file()
```

## Dependencies

This plugin currently depends on [snacks.picker](https://github.com/folke/snacks.nvim)

## Installation

Install it like any other plugin. For example, if using `LazyVim` as your
package manager:


```lua
{
  'AndresYague/mark-jumps.nvim',
  opts = {},
}
```

It can also be initialized through a `setup` call:

```lua
require('mark-jumps').setup(opts)
```

## Configuration

### Defalt options

The default options are

```lua
opts = {
  mark_names = { 'A', 'B', 'C', 'D' } -- Which marks can the plugin use
  prefix = '<leader>' -- Prefix for file jump, <prefix>N goes to the Nth marked file
}
```

### Example keymaps

These example keymaps set-up the full api

```lua
vim.keymap.set(
  'n',
  '<leader>ja',
  require('mark-jumps').mark_add,
  { desc = 'Add file to marks' }
)
vim.keymap.set(
  'n',
  '<leader>jr',
  require('mark-jumps').remove_marks,
  { desc = 'Remove all marks' }
)
vim.keymap.set(
  'n',
  '<leader>jd',
  require('mark-jumps').remove_filename,
  { desc = 'Remove mark from this file' }
)
vim.keymap.set(
  'n',
  '<leader>js',
  require('mark-jumps').choose_file,
  { desc = 'Choose go to file' }
)
vim.keymap.set(
  'n',
  '<leader>jx',
  require('mark-jumps').choose_delete,
  { desc = 'Choose delete mark' }
)
vim.keymap.set(
  'n',
  '<leader>jc',
  require('mark-jumps').choose_change,
  { desc = 'Choose change mark' }
)
```

## Inspiration

This plugin is inspired by [harpoon](https://github.com/ThePrimeagen/harpoon/tree/harpoon2)

## TODO

- Remove snacks dependency

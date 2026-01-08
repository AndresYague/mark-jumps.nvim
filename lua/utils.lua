M = {}

---Open cache in floating window
---@param filename string -- File to open
---@param relsize number? -- Relative size of the floating window to the editor window
---@return string[]
M.edit_cache = function(filename, relsize)
  relsize = relsize or 0.5
  local bufnr = vim.api.nvim_create_buf(false, true)
  local new_buffer

  -- Hook manager group
  local hook_group =
    vim.api.nvim_create_augroup("hook-manager", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = hook_group,
    buffer = bufnr,
    callback = function()
      vim.api.nvim_buf_set_keymap(bufnr, "n", "q", ":q!<CR>", {})
      vim.api.nvim_buf_set_keymap(bufnr, "n", "<ESC>", ":q!<CR>", {})
    end,
    once = true,
  })

  vim.api.nvim_create_autocmd("BufWinLeave", {
    group = hook_group,
    buffer = bufnr,
    callback = function()
      new_buffer = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
    end,
    once = true,
  })

  -- Open new window
  vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",

    -- Center window and give it the desired relative size to the editor
    row = math.floor(vim.o.lines * (1 - relsize) * 0.5),
    col = math.floor(vim.o.columns * (1 - relsize) * 0.5),
    height = math.floor(vim.o.lines * relsize),
    width = math.floor(vim.o.columns * relsize),
    border = "rounded",
    style = "minimal",
  })

  -- Write to buffer
  local str = { "This is a test", "And let's test" }
  vim.api.nvim_buf_set_lines(bufnr, 0, 0, true, str)

  -- Return new_buffer
  return new_buffer
end

return M

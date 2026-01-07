M = {}

---Open cache in floating window
---@param filename string
---@param relsize number?
---@return nil
M.edit_cache = function(filename, relsize)
  -- Relative size of the picker
  -- to the editor window
  relsize = relsize or 0.4

  local bufnr = vim.api.nvim_create_buf(false, true)

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

  vim.cmd.edit(filename)
end

return M

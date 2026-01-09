M = {}

-- Create a bufnr already for the cache picker
local cache_bufnr = vim.api.nvim_create_buf(false, true)
local pretty_table
---@type string[]
local pretty_lines

-- What project are we on?
local root = vim.fs.root(0, {
  ".git",
  ".helix",
  ".project",
  "package.json",
  "pom.xml",
  "pyproject.toml",
})

-- Cache utility functions

-- Create the cache directory
local cache_dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "fish-files")
vim.fn.mkdir(cache_dir, "p")

-- Get the filename for the cache
local cache_file
if root then
  cache_file = vim.fs.joinpath(cache_dir, root:gsub("%/", "%%") .. ".cache")
else
  cache_file = vim.fs.joinpath(cache_dir, "_general_.cache")
end

---Write files to cache
---@param filename_list string[]
---@return nil
local write_to_cache = function(filename_list)
  local file_write = io.open(cache_file, "w+")
  if file_write then
    for _, fname in ipairs(filename_list) do
      file_write:write(fname .. "\n")
    end
    file_write:close()
  else
    vim.notify("fish-files: could not cache file", vim.log.levels.INFO)
  end
end

---Manage the cache, return true if the cache has been added to "pretty_table",
---false if there was an error
---@return boolean
local get_pretty_table = function()
  -- Read current cache
  ---@type string[]
  local current_cache = {}
  local file_read = io.open(cache_file, "r")
  if file_read then
    for line in file_read:lines() do
      current_cache[#current_cache + 1] = line
    end
  else
    return false
  end

  -- Make table of pretty keys and full filenames
  pretty_table = {}
  pretty_lines = {}
  for _, line in ipairs(current_cache) do
    local pretty
    if root then
      pretty = line:sub(root:len() + 2)
    else
      pretty = line
    end

    pretty_table[pretty] = line
    pretty_lines[#pretty_lines + 1] = pretty
  end

  return true
end

---Read the pretty table keys from the given buffer and write the actual
---filenames corresponding to them in the cache
---@param bufnr integer
---@return nil
local pretty_bufr_to_cache = function(bufnr)
  local buflines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)

  local new_buffer = {}
  for _, key in ipairs(buflines) do
    new_buffer[#new_buffer + 1] = pretty_table[key]
  end

  write_to_cache(new_buffer)
end

---Open cache in floating window, return picked file if it exists
---@param goto_file string[] -- Store the picked string
---@param min_relsize number? -- Relative size of the floating window to the editor window
---@param max_relsize number? -- Relative size of the floating window to the editor window
---@return string?
M.edit_cache = function(goto_file, min_relsize, max_relsize)
  max_relsize = max_relsize or 0.5
  min_relsize = min_relsize or 0.2

  -- Hook manager group
  local hook_group =
    vim.api.nvim_create_augroup("hook-manager", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = hook_group,
    buffer = cache_bufnr,
    callback = function()
      -- Exiting keymaps
      vim.api.nvim_buf_set_keymap(cache_bufnr, "n", "q", ":q!<CR>", {})
      vim.api.nvim_buf_set_keymap(cache_bufnr, "n", "<ESC>", ":q!<CR>", {})

      -- Saving keymaps
      vim.api.nvim_buf_set_keymap(cache_bufnr, "ca", "w", "", {
        callback = function()
          pretty_bufr_to_cache(cache_bufnr)
        end,
      })
      vim.api.nvim_buf_set_keymap(cache_bufnr, "ca", "wq", "", {
        callback = function()
          pretty_bufr_to_cache(cache_bufnr)
          vim.cmd("q!")
        end,
      })
      vim.api.nvim_buf_set_keymap(cache_bufnr, "ca", "x", "", {
        callback = function()
          pretty_bufr_to_cache(cache_bufnr)
          vim.cmd("q!")
        end,
      })
      vim.api.nvim_buf_set_keymap(cache_bufnr, "n", "ZZ", "", {
        callback = function()
          pretty_bufr_to_cache(cache_bufnr)
          vim.cmd("q!")
        end,
      })

      -- Pick value
      vim.api.nvim_buf_set_keymap(cache_bufnr, "n", "<CR>", "", {
        callback = function()
          goto_file[#goto_file + 1] =
            pretty_table[vim.api.nvim_get_current_line()]
          vim.cmd("q!")
        end,
      })
    end,
    once = true,
  })

  -- Clear buffer
  vim.api.nvim_buf_set_lines(cache_bufnr, 0, -1, true, { "" })

  -- Get window size

  local max_cols = 0
  if get_pretty_table() then
    -- Write to buffer
    local str = {}
    for _, pretty in pairs(pretty_lines) do
      str[#str + 1] = pretty
      max_cols = vim.fn.max({ max_cols, pretty:len() })
    end
    vim.api.nvim_buf_set_lines(cache_bufnr, 0, -1, true, str)
  end

  local use_rows = math.max(
    math.min(vim.o.lines * max_relsize, #pretty_lines),
    vim.o.lines * min_relsize
  )
  local use_cols = math.max(
    math.min(vim.o.columns * max_relsize, max_cols),
    vim.o.columns * min_relsize
  )

  -- Open new window
  vim.api.nvim_open_win(cache_bufnr, true, {
    relative = "editor",

    -- Center window and give it the desired relative size to the editor
    row = math.floor((vim.o.lines - use_rows) * 0.5),
    col = math.floor((vim.o.columns - use_cols) * 0.5),
    height = math.floor(use_rows),
    width = math.floor(use_cols),
    border = "rounded",
    style = "minimal",
    title = "Hooked files",
    title_pos = "center",
  })
end

M.cache_file = cache_file
M.write_to_cache = write_to_cache

return M

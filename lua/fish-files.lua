M = {}

-- Group for autocommands
local fish_group = vim.api.nvim_create_augroup("fish-files", { clear = true })

-- Bufnr related variables
local cache_bufnr = -1

---@type string[] Show files as pretty names in buffer
local pretty_lines
---@type string[] List of all files hooked
local filename_list = {}
local pretty_table

-- Other needed variables
local goto_file = {}
local keymaps = 0
local prefix

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
---@param filenames string[]?
---@return nil
local write_to_cache = function(filenames)
  filenames = filenames or filename_list

  local file_write = io.open(cache_file, "w+")
  if file_write then
    for _, fname in ipairs(filenames) do
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

---Shorten a filename for easier visualization
---@param filename string Name of the file
---@return string
local shorten_filename = function(filename)
  local pretty_line = nil
  if root then
    pretty_line = filename:sub(root:len() + 2)
  end
  if pretty_line and pretty_line:len() <= 30 then
    return pretty_line
  else
    return vim.fs.joinpath(
      vim.fs.basename(vim.fs.dirname(filename)),
      vim.fs.basename(filename)
    )
  end
end

---Open a file, loading the view
---@param filename string Name of the file
---@return nil
local reel_file = function(filename)
  if vim.api.nvim_buf_get_name(0) ~= "" then
    vim.cmd.mkview()
  end
  vim.cmd.edit(filename)
  pcall(vim.cmd.loadview(), "")
  -- vim.cmd.filetype("detect") -- Detecting again the filetype to trigger LSP and colorscheme
end

---Add keymap for the filename
---@param filename string Name of the file
---@return nil
local add_keymap = function(filename)
  -- Increment keymaps
  keymaps = keymaps + 1
  local index = keymaps
  vim.keymap.set("n", prefix .. index, function()
    reel_file(filename)
  end, { desc = "Reel file: " .. shorten_filename(filename) })
end

---Clean and re-create all the keymaps
---@return nil
local re_index_keymaps = function()
  -- Clean the keymaps
  for idx = 1, keymaps do
    vim.api.nvim_del_keymap("n", prefix .. idx)
  end
  keymaps = 0

  -- Now create them again
  for _, fname in ipairs(filename_list) do
    add_keymap(fname)
  end
end

---Normalize the filename. If "filename" is not provided, take the current
---buffer
---@param filename string? Name of the file
---@return string
local normalize_fname = function(filename)
  -- Get current filename
  if not filename then
    filename = vim.api.nvim_buf_get_name(0)
  end

  return vim.fs.normalize(vim.fs.abspath(filename))
end

---Add a keymap for the filename
---@param filename string? Name of the file
---@return nil
local add_hook = function(filename)
  -- Normalize current filename
  filename = normalize_fname(filename)

  -- Check if filename is already in array
  for _, fname in ipairs(filename_list) do
    if fname == filename then
      return
    end
  end

  -- Add filename and keymap
  filename_list[#filename_list + 1] = filename
  add_keymap(filename)
end

---@param filename string? Name of the file
---@param do_re_index boolean? Re-index default True
---@return nil
local remove_hook = function(filename, do_re_index)
  if do_re_index == nil then
    do_re_index = true
  end

  -- Normalize current filename
  filename = normalize_fname(filename)

  for idx, fname in ipairs(filename_list) do
    if fname == filename then
      table.remove(filename_list, idx)
      break
    end
  end

  if do_re_index then
    re_index_keymaps()
  end
end

-- Cache utility functions

---Read cache file
---@return nil
local read_cache = function()
  -- In case we have some files in memory, unload them
  filename_list = {}
  re_index_keymaps()

  local file_read = io.open(cache_file, "r")
  if file_read then
    for line in file_read:lines() do
      add_hook(line)
    end
  end
end

---Open cache in floating window, return picked file if it exists
---@param min_relsize number? -- Relative size of the floating window to the editor window
---@param max_relsize number? -- Relative size of the floating window to the editor window
---@return string?
local edit_cache = function(min_relsize, max_relsize)
  max_relsize = max_relsize or 0.5
  min_relsize = min_relsize or 0.2

  if not vim.api.nvim_buf_is_valid(cache_bufnr) then
    cache_bufnr = vim.api.nvim_create_buf(false, true)

    -- Hook manager group
    vim.api.nvim_create_autocmd("BufEnter", {
      group = vim.api.nvim_create_augroup("hook-manager", { clear = true }),
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
            vim.cmd("doautocmd User FishReelFile")
          end,
        })
      end,
      once = true,
    })

    -- When the cache is changed, read it
    vim.api.nvim_create_autocmd("BufWinLeave", {
      buffer = cache_bufnr,
      group = vim.api.nvim_create_augroup(
        "fish-files-read-cache",
        { clear = true }
      ),

      -- We either changed the buffer or selected a file
      callback = function()
        read_cache()
      end,
    })
  end

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
    title = "󰛢 Hooked files 󰛢",
    title_pos = "center",
  })
end

---@param opts {prefix: string}? Options for the plugin
---@return nil
M.setup = function(opts)
  opts = opts or {}
  prefix = opts.prefix or "<leader>"

  -- Read the cache file to the filenames
  read_cache()

  -- When we pick a file, go to it
  vim.api.nvim_create_autocmd("User", {
    group = fish_group,
    pattern = "FishReelFile",

    callback = function()
      if #goto_file > 0 then
        local index
        for idx, file in ipairs(filename_list) do
          if file == goto_file[1] then
            goto_file = {}
            index = idx
            break
          end
        end

        -- Just send the keys to nvim, as if the user typed it
        if index then
          local keys =
            vim.api.nvim_replace_termcodes(prefix .. index, true, false, true)
          vim.api.nvim_feedkeys(keys, "t", false)
        end
      end
    end,
  })

  -- Save the filenames to the cache file when leaving nvim
  vim.api.nvim_create_autocmd({ "VimLeave" }, {
    group = fish_group,
    callback = function()
      write_to_cache()
    end,
    once = true,
  })
end

---Function to remove all filenames
---@return nil
M.unhook_all_files = function()
  filename_list = {}
  re_index_keymaps()
end

M.manage_hooks = function()
  -- Write to the cache file
  write_to_cache()

  -- Open the cache file to edit
  edit_cache()

  -- The autocmd below makes sure we get the information after editing the
  -- cache
end

M.add_hook = add_hook
M.remove_hook = remove_hook

return M

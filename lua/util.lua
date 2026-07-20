Util = {}

-- Bufnr related variables

---@type string[] Show files as pretty names in buffer
Util.pretty_lines = nil
---@type string[] List of all files hooked
Util.filename_list = {}
Util.pretty_table = nil

-- Other needed variables
local keymaps = 0
Util.prefix = nil

-- What project are we on?
local root = vim.fs.root(0, {
  ".git",
  ".helix",
  ".jj",
  ".project",
  "package.json",
  "pom.xml",
  "pyproject.toml",
})

-- Cache utility functions

-- Create the cache directory
local cache_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "fish-files")
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
Util.write_to_cache = function(filenames)
  filenames = filenames or Util.filename_list

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
Util.get_pretty_table = function()
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
  Util.pretty_table = {}
  Util.pretty_lines = {}
  for _, line in ipairs(current_cache) do
    local pretty
    if root then
      pretty = line:sub(root:len() + 2)
    else
      pretty = line
    end

    Util.pretty_table[pretty] = line
    Util.pretty_lines[#Util.pretty_lines + 1] = pretty
  end

  return true
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
  vim.cmd.loadview({ mods = { silent = true } })
end

---Add keymap for the filename
---@param filename string Name of the file
---@return nil
local add_keymap = function(filename)
  -- Increment keymaps
  keymaps = keymaps + 1
  local index = keymaps
  vim.keymap.set("n", Util.prefix .. index, function()
    reel_file(filename)
  end, { desc = "Reel file: " .. shorten_filename(filename) })
end

---Clean and re-create all the keymaps
---@return nil
Util.re_index_keymaps = function()
  -- Clean the keymaps
  for idx = 1, keymaps do
    vim.api.nvim_del_keymap("n", Util.prefix .. idx)
  end
  keymaps = 0

  -- Now create them again
  for _, fname in ipairs(Util.filename_list) do
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
Util.add_hook = function(filename)
  -- Normalize current filename
  filename = normalize_fname(filename)

  -- Check if filename is already in array
  for _, fname in ipairs(Util.filename_list) do
    if fname == filename then
      return
    end
  end

  -- Add filename and keymap
  Util.filename_list[#Util.filename_list + 1] = filename
  add_keymap(filename)
end

---@param filename string? Name of the file
---@param do_re_index boolean? Re-index default True
---@return nil
Util.remove_hook = function(filename, do_re_index)
  if do_re_index == nil then
    do_re_index = true
  end

  -- Normalize current filename
  filename = normalize_fname(filename)

  for idx, fname in ipairs(Util.filename_list) do
    if fname == filename then
      table.remove(Util.filename_list, idx)
      break
    end
  end

  if do_re_index then
    Util.re_index_keymaps()
  end
end

-- Cache utility functions

---Read cache file
---@return nil
Util.read_cache = function()
  -- In case we have some files in memory, unload them
  Util.filename_list = {}
  Util.re_index_keymaps()

  local file_read = io.open(cache_file, "r")
  if file_read then
    for line in file_read:lines() do
      Util.add_hook(line)
    end
  end
end

return Util

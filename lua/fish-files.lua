local Snacks = require("snacks")
local edit_cache = require("utils").edit_cache
local keymaps = 0
local prefix

---@type string[]
local filename_list = {}

-- What project are we on?
local root = vim.fs.root(0, {
  ".git",
  ".helix",
  ".project",
  "package.json",
  "pom.xml",
  "pyproject.toml",
})

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

M = {}

---Open a filename, loading the view
---@param filename string?
---@return nil
local reel_file = function(filename)
  if vim.api.nvim_buf_get_name(0) ~= "" then
    vim.cmd.mkview()
  end
  vim.cmd.edit(filename)
  pcall(vim.cmd.loadview(), "")
end

---Normalize the filename. If "filename" is not provided,
---take the current buffer
---@param filename string?
---@return string
local normalize_fname = function(filename)
  -- Get current filename
  if not filename then
    filename = vim.api.nvim_buf_get_name(0)
  end

  return vim.fs.normalize(vim.fs.abspath(filename))
end

---Shorten a filename for easier visualization
---@param filename string
---@return string
local shorten_filename = function(filename)
  return vim.fs.joinpath(
    vim.fs.basename(vim.fs.dirname(filename)),
    vim.fs.basename(filename)
  )
end

---Add keymap for the filename
---@param filename string
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

---Add a keymap for the filename
---@param filename string?
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

---@param filename string?
---@param do_re_index boolean?
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

---Perform an action on a chosen filename
---@param action string
---@param prompt string
---@return nil
local file_action = function(action, prompt)
  local short_fnames = {}
  for idx, fname in ipairs(filename_list) do
    short_fnames[idx] = shorten_filename(fname)
  end
  Snacks.picker.select(short_fnames, { prompt = prompt }, function(filename)
    -- User canceled
    if not filename then
      return
    end

    if action == "go" then
      reel_file(filename)
    elseif action == "delete" then
      -- Remove filename
      remove_hook(filename)
    end
  end)
end

---Function to remove all filenames
---@return nil
M.unhook_all_files = function()
  for _, fname in ipairs(filename_list) do
    remove_hook(fname, false)
  end
  re_index_keymaps()
end

-- Define the functions that use file_action

M.choose_reel_file = function()
  file_action("go", "Choose file to reel")
end
M.choose_remove_hook = function()
  file_action("delete", "Choose file to unhook")
end

-- Cache utility functions

---Write files to cache
---@return nil
local write_to_cache = function()
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

M.manage_hooks = function()
  -- Write to the cache file
  write_to_cache()

  -- Make the filepath openable by vim
  local openable_cache = cache_file:gsub("%%", "%\\%%")

  -- Open the cache file to edit
  edit_cache(openable_cache)

  -- The autocmd below makes sure we get the information after editing the
  -- cache
end

---@param opts {prefix: string}?
---@return nil
M.setup = function(opts)
  opts = opts or {}
  prefix = opts.prefix or "<leader>"

  -- Read the cache file to the filenames
  read_cache()

  local fish_group = vim.api.nvim_create_augroup("Fish-files", { clear = true })

  -- When the cache is changed, read it
  vim.api.nvim_create_autocmd({ "BufWinLeave" }, {
    pattern = cache_file,
    group = fish_group,
    callback = read_cache,
  })

  -- Save the filenames to the cache file when leaving nvim
  vim.api.nvim_create_autocmd({ "VimLeave" }, {
    group = fish_group,
    callback = write_to_cache,
    once = true,
  })
end

M.add_hook = add_hook
M.remove_hook = remove_hook

return M

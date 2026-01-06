local Snacks = require("snacks")
local keymaps = {}
local filenames = {}

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
local cache_dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "mark-jumps")
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
local edit_file = function(filename)
  if vim.api.nvim_buf_get_name(0) ~= "" then
    vim.cmd.mkview()
  end
  vim.cmd.edit(filename)
  pcall(vim.cmd.loadview())
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

---Clean and re-create all the keymaps
---@return nil
local re_index_keymaps = function()
  -- Clean the keymaps
  for _, keymap in ipairs(keymaps) do
    vim.api.nvim_del_keymap("n", M.opts.prefix .. keymap)
  end
  keymaps = {}

  -- Now create them again
  for idx, fname in ipairs(filenames) do
    -- Add the keymaps
    vim.keymap.set("n", M.opts.prefix .. idx, function()
      edit_file(fname)
    end, { desc = "File: " .. fname })
    table.insert(keymaps, idx)
  end
end

---Add a keymap for the filename
---@param filename string?
---@return nil
M.add_filename = function(filename)
  -- Normalize current filename
  filename = normalize_fname(filename)

  -- Check if filename is already in array
  for _, fname in ipairs(filenames) do
    if fname == filename then
      return
    end
  end

  table.insert(filenames, filename)

  -- Shorten filename
  filename = vim.fs.joinpath(
    vim.fs.basename(vim.fs.dirname(filename)),
    vim.fs.basename(filename)
  )

  -- Add the keymap
  local fname_index = #filenames
  vim.keymap.set("n", M.opts.prefix .. fname_index, function()
    edit_file(filenames[fname_index])
  end, { desc = "File: " .. filename })
  keymaps[#keymaps + 1] = fname_index
end

---@param filename string?
---@param do_re_index boolean?
---@return nil
M.remove_filename = function(filename, do_re_index)
  if do_re_index == nil then
    do_re_index = true
  end

  -- Normalize current filename
  filename = normalize_fname(filename)

  for idx, fname in ipairs(filenames) do
    if fname == filename then
      table.remove(filenames, idx)
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
  Snacks.picker.select(filenames, { prompt = prompt }, function(filename)
    -- User canceled
    if not filename then
      return
    end

    if action == "go" then
      edit_file(filename)
    elseif action == "delete" then
      -- Remove filename
      M.remove_filename(filename)
    elseif action == "change" then
      -- Remove this filename and add the current file
      M.remove_filename(filename)
      M.add_filename()
    end
  end)
end

---Function to remove all filenames
---@return nil
M.remove_all = function()
  for _, fname in ipairs(filenames) do
    M.remove_filename(fname, false)
  end
  re_index_keymaps()
end

-- Define the functions use file_action

M.choose_file = function()
  file_action("go", "Choose go to file")
end
M.choose_delete = function()
  file_action("delete", "Choose delete filename")
end
M.choose_change = function()
  file_action("delete", "Choose change filename")
end

---@param opts {prefix: string}?
---@return nil
M.setup = function(opts)
  M.opts = opts or {}
  M.opts.prefix = M.opts.prefix or "<leader>"

  -- Read the cache file to the filenames
  local file_read = io.open(cache_file, "r")
  if file_read then
    for line in file_read:lines() do
      M.add_filename(line)
    end
  end

  -- Save the filenames to the cache file when leaving nvim
  vim.api.nvim_create_autocmd("VimLeave", {
    group = vim.api.nvim_create_augroup("Files saving", { clear = true }),
    callback = function()
      local file_write = io.open(cache_file, "w+")
      if file_write then
        for _, fname in ipairs(filenames) do
          file_write:write(fname .. "\n")
        end
        file_write:close()
      else
        vim.notify("mark-jumps: could not cache file", vim.log.levels.INFO)
      end
    end,
    once = true,
  })
end

return M

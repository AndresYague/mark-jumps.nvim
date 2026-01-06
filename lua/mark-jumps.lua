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
local re_index = function()
  -- Clean the keymaps
  for _, keymap in ipairs(keymaps) do
    vim.api.nvim_del_keymap("n", M.opts.prefix .. keymap)
  end

  -- Now create them again
  for _, fname in ipairs(filenames) do
    M.mark_add(fname)
  end
end

---Add a keymap for the filename
---@param filename string?
---@return nil
M.mark_add = function(filename)
  -- Normalize current filename
  filename = normalize_fname(filename)

  -- Check if filename is already in array
  local already_there = false
  for _, fname in ipairs(filenames) do
    if fname == filename then
      already_there = true
      break
    end
  end

  if not already_there then
    table.insert(filenames, filename)
  end

  -- Shorten filename
  filename = vim.fs.joinpath(
    vim.fs.basename(vim.fs.dirname(filename)),
    vim.fs.basename(filename)
  )

  -- Add the keymap
  local fname_index = #filenames
  vim.keymap.set("n", M.opts.prefix .. fname_index, function()
    vim.cmd.edit(filenames[fname_index])
  end, { desc = "File: " .. filename })
  keymaps[#keymaps + 1] = fname_index
end

---@param filename string?
---@return nil
M.remove_filename = function(filename)
  -- Normalize current filename
  filename = normalize_fname(filename)

  for idx, fname in ipairs(filenames) do
    if fname == filename then
      table.remove(filenames, idx)
      break
    end
  end
end

---Index all existing marks so they are not overwritten
---@return nil
local index_all_marks = function()
  -- Read the cached file and save to filenames
  local file_read = io.open(cache_file, "r")
  if file_read then
    for line in file_read:lines() do
      M.mark_add(line)
    end
  end
end

---Perform an action on a chosen mark
---@param action string
---@param prompt string
---@return nil
local choose_mark = function(action, prompt)
  Snacks.picker.select(filenames, { prompt = prompt }, function(filename)
    -- User canceled
    if not filename then
      return
    end

    if action == "go" then
      vim.cmd.edit(filename)
    elseif action == "delete" then
      -- Remove mark from nvim
      M.remove_filename(filename)
      re_index()
    elseif action == "change" then
      -- Remove this mark and then create another in the current file
      M.remove_filename(filename)
      re_index()
      M.mark_add()
    end
  end)
end

---Function to remove all marks
---@return nil
M.remove_marks = function()
  for _, fname in ipairs(filenames) do
    M.remove_filename(fname)
  end
  re_index()
end

-- Define the functions use choose_mark

M.choose_file = function()
  choose_mark("go", "Choose go to file")
end
M.choose_delete = function()
  choose_mark("delete", "Choose delete mark")
end
M.choose_change = function()
  choose_mark("delete", "Choose change mark")
end

---@param opts {prefix: string}?
---@return nil
M.setup = function(opts)
  M.opts = opts or {}
  M.opts.prefix = M.opts.prefix or "<leader>"

  -- Run the mark indexing once vim has loaded
  vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("Files indexing", { clear = true }),
    callback = function()
      index_all_marks()
    end,
    once = true,
  })

  -- Run the mark indexing once we leave vim
  vim.api.nvim_create_autocmd("VimLeave", {
    group = vim.api.nvim_create_augroup("Files saving", { clear = true }),
    callback = function()
      local file_write = io.open(cache_file, "w+")
      if file_write then
        for _, fname in ipairs(filenames) do
          file_write:write(fname .. "\n")
          file_write:close()
        end
      else
        vim.notify("mark-jumps: could not cache file", vim.log.levels.INFO)
      end
    end,
    once = true,
  })
end

return M

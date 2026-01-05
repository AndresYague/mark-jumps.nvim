local Snacks = require("snacks")
local marks = {}
local keymaps = {}

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

---Go to a mark saving the view before leaving and restoring it
---after arriving
---@param mark string
---@return nil
local go_to_mark = function(mark)
  if vim.api.nvim_buf_get_name(0) ~= "" then
    vim.cmd.mkview()
  end
  vim.api.nvim_feedkeys("`" .. mark, "ixn", false)
  pcall(vim.cmd.loadview())
end

---Add a filename to the cache_file
---@param mark string?
---@param filename string?
---@return nil
M.mark_add = function(mark, filename)
  -- Get current filename
  if not filename then
    filename = vim.api.nvim_buf_get_name(0)
  else
    filename = vim.fs.abspath(filename)
  end

  -- Figure out if file already in cache_file, in that case we can just exit
  local file_read = io.open(cache_file, "r")
  if file_read then
    for line in file_read:lines() do
      vim.print(line)
      if line == filename then
        vim.print(line, "Exiting function")
        return nil
      end
    end
  end

  -- Write to cache_file
  local file_write = io.open(cache_file, "a+")
  if file_write then
    file_write:write(filename .. "\n")
    file_write:close()
  else
    vim.print("could not open")
  end

  -- if not mark then
  --   local insert_mark = { did = false, index = 0 }
  --
  --   -- Do not add more than one mark per file
  --   local bufname = vim.api.nvim_buf_get_name(0)
  --   for _, mrk in ipairs(marks) do
  --     if
  --       bufname
  --       == vim.fs.abspath(vim.fs.normalize(vim.api.nvim_get_mark(mrk, {})[4]))
  --     then
  --       return nil
  --     end
  --   end
  --
  --   -- Add the mark to the list
  --   if #marks == 0 then
  --     marks = { M.opts.mark_names[1] }
  --     insert_mark.did = true
  --     insert_mark.index = #marks
  --   else
  --     for idx, mark_name in ipairs(M.opts.mark_names) do
  --       if marks[idx] ~= mark_name then
  --         table.insert(marks, idx, mark_name)
  --         insert_mark.did = true
  --         insert_mark.index = idx
  --         break
  --       end
  --     end
  --
  --     -- Tell user to change mark
  --     if not insert_mark.did then
  --       vim.notify(
  --         "Maximum number of marks reached, please choose to change a "
  --           .. "mark instead with require('makr-jumps').choose_change()"
  --           .. " or add more marks to your configuration",
  --         vim.log.levels.INFO,
  --         { title = "Too many marks" }
  --       )
  --
  --       return nil
  --     end
  --   end
  --
  --   -- Add the mark to the file
  --   local cursor = vim.api.nvim_win_get_cursor(0)
  --   vim.api.nvim_buf_set_mark(
  --     0,
  --     marks[insert_mark.index],
  --     cursor[1],
  --     cursor[2],
  --     {}
  --   )
  -- else
  --   marks[#marks + 1] = mark
  -- end
  --
  -- -- Save the current size of marks to avoid
  -- -- capturing the dynamic #marks
  -- local mark_index = #marks
  --
  -- -- Get filename for mark
  -- if not filename then
  --   filename = vim.api.nvim_buf_get_name(0)
  -- end
  --
  -- -- Shorten filename
  -- filename = vim.fs.joinpath(
  --   vim.fs.basename(vim.fs.dirname(filename)),
  --   vim.fs.basename(filename)
  -- )
  --
  -- -- Add the keymap
  -- vim.keymap.set("n", M.opts.prefix .. mark_index, function()
  --   go_to_mark(marks[mark_index])
  -- end, { desc = "File: " .. filename })
  -- keymaps[#keymaps + 1] = mark_index
end

---@param mark_arr string[]
---@return string[]
local filename_array = function(mark_arr)
  local filename_arr = {}
  for _, mark in ipairs(mark_arr) do
    local markinfo = vim.api.nvim_get_mark(mark, {})
    filename_arr[#filename_arr + 1] = mark .. " -> " .. markinfo[4]
  end

  return filename_arr
end

---Index all existing marks so they are not overwritten
---@return nil
local index_all_marks = function()
  -- Clean the table and keymaps
  for _, keymap in ipairs(keymaps) do
    vim.api.nvim_del_keymap("n", M.opts.prefix .. keymap)
  end

  marks = {}
  keymaps = {}

  -- Re-index
  for _, tbl in ipairs(vim.fn.getmarklist()) do
    -- Take only the A-Z marks
    if tbl.mark:match("'[A-Z]") then
      -- Filter by project as well

      -- Check if tbl.file is a substring of root
      if
        root
        and (
          vim.fs.abspath(vim.fs.normalize(tbl.file)):sub(1, root:len())
          ~= root
        )
      then
        goto continue
      end

      M.mark_add(tbl.mark:sub(2), tbl.file)
    end
    ::continue::
  end
end

---Perform an action on a chosen mark
---@param action string
---@param prompt string
---@return nil
local choose_mark = function(action, prompt)
  Snacks.picker.select(
    filename_array(marks),
    { prompt = prompt },
    function(choice)
      -- User canceled
      if not choice then
        return
      end

      -- Get only the mark name
      local mark = choice:sub(1, 1)

      if action == "go" then
        go_to_mark(mark)
      elseif action == "delete" then
        -- Remove mark from nvim
        vim.api.nvim_del_mark(mark)

        -- Re-index marks
        index_all_marks()
      elseif action == "change" then
        -- Remove this mark and then create another in the current file
        vim.api.nvim_del_mark(mark)
        index_all_marks()
        M.mark_add()
      end
    end
  )
end

---Function to remove all marks
---@return nil
M.remove_marks = function()
  for _, mark in ipairs(marks) do
    vim.api.nvim_del_mark(mark)
  end

  index_all_marks()
end

---Remove mark from current file
M.delete_from_file = function()
  for _, tbl in ipairs(vim.fn.getmarklist()) do
    -- Take only the A-Z marks
    if tbl.mark:match("'[A-Z]") then
      if
        vim.fs.abspath(vim.fs.normalize(tbl.file))
        == vim.api.nvim_buf_get_name(0)
      then
        vim.api.nvim_buf_del_mark(0, tbl.mark:sub(2))
        break
      end
    end
  end

  index_all_marks()
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

---@param opts {mark_names: string[], prefix: string}?
---@return nil
M.setup = function(opts)
  M.opts = opts or {}

  M.opts.mark_names = M.opts.mark_names or { "A", "B", "C", "D" }
  M.opts.prefix = M.opts.prefix or "<leader>"

  -- Run the mark indexing once vim has loaded
  vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("Marks indexing", { clear = true }),
    callback = function()
      index_all_marks()
    end,
    once = true,
  })
end

return M

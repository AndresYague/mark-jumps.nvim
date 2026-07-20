local util = require("util")

M = {}

-- Bufnr related variables
local cache_bufnr = -1

-- Other needed variables
local goto_file

---Read the pretty table keys from the given buffer and write the actual
---filenames corresponding to them in the cache
---@param bufnr integer
---@return nil
local pretty_bufr_to_cache = function(bufnr)
  local buflines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)

  local new_buffer = {}
  for _, key in ipairs(buflines) do
    new_buffer[#new_buffer + 1] = util.pretty_table[key]
  end

  util.write_to_cache(new_buffer)
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
            goto_file = util.pretty_table[vim.api.nvim_get_current_line()]

            -- Handle going to file
            if goto_file then
              -- Find the index of the chosen file
              local index
              for idx, file in ipairs(util.filename_list) do
                if file == goto_file then
                  goto_file = nil
                  index = idx
                  break
                end
              end

              -- Just send the keys to nvim, as if the user typed it
              if index then
                local keys = vim.api.nvim_replace_termcodes(
                  util.prefix .. index,
                  true,
                  false,
                  true
                )
                vim.api.nvim_feedkeys(keys, "t", false)
              end
            end
            vim.cmd("q!")
          end,
        })
      end,
    })

    -- When the cache is changed, read it
    vim.api.nvim_create_autocmd({ "BufLeave", "BufWinLeave" }, {
      buffer = cache_bufnr,
      group = vim.api.nvim_create_augroup(
        "fish-files-read-cache",
        { clear = true }
      ),

      -- We either changed the buffer or selected a file
      callback = function()
        vim.cmd("q!")
        util.read_cache()
      end,
    })
  end

  -- Clear buffer
  vim.api.nvim_buf_set_lines(cache_bufnr, 0, -1, true, { "" })

  -- Get window size

  local max_cols = 0
  if util.get_pretty_table() then
    -- Write to buffer
    local str = {}
    for _, pretty in pairs(util.pretty_lines) do
      str[#str + 1] = pretty
      max_cols = vim.fn.max({ max_cols, pretty:len() })
    end
    vim.api.nvim_buf_set_lines(cache_bufnr, 0, -1, true, str)
  end

  local use_rows = math.max(
    math.min(vim.o.lines * max_relsize, #util.pretty_lines),
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
  util.prefix = opts.prefix or "<leader>"

  -- Read the cache file to the filenames
  util.read_cache()

  -- Group for autocommands
  local fish_group = vim.api.nvim_create_augroup("fish-files", { clear = true })

  -- Save the filenames to the cache file when leaving nvim
  vim.api.nvim_create_autocmd({ "VimLeave" }, {
    group = fish_group,
    callback = function()
      util.write_to_cache()
    end,
  })
end

---Function to remove all filenames
---@return nil
M.unhook_all_files = function()
  util.filename_list = {}
  util.re_index_keymaps()
end

M.manage_hooks = function()
  -- Write to the cache file
  util.write_to_cache()

  -- Open the cache file to edit
  edit_cache()

  -- The autocmd below makes sure we get the information after editing the
  -- cache
end

M.add_hook = util.add_hook
M.remove_hook = util.remove_hook

return M

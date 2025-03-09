-- pretty-ts-errors.nvim
-- A Neovim plugin to improve TypeScript error messages

local M = {}

-- Default configuration
M.config = {
  -- Whether to enable the plugin by default
  enabled = true,

  -- Maximum height of the error window
  max_height = 12,

  -- Styling options
  styling = {
    -- Prefix for each simplified error message
    prefix = "→ ",

    -- Highlight colors
    colors = {
      error = "#FF5555",
      warning = "#FFAA55",
      info = "#55AAFF",
    },
  },

  -- Prettify error patterns (regex replacements)
  prettify_patterns = {
    -- Replace TS specific language
    {
      pattern = "Type '(.+)' is not assignable to type '(.+)'",
      replace = "Expected type '$2', but got '$1'"
    },

    -- Simplify property errors
    {
      pattern = "Property '(.+)' does not exist on type '(.+)'",
      replace = "The object '$2' doesn't have a property named '$1'"
    },

    -- Simplify missing parameters
    {
      pattern = "Expected (%d+) arguments, but got (%d+)",
      replace = "This function takes $1 parameters, but you provided $2"
    },
  },
}

-- Current state
local state = {
  enabled = true,
  diagnostics_ns = nil,
  error_win = nil,
  error_buf = nil,
}

-- Create a new buffer for the error display
local function create_error_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
  return buf
end

-- Create or update error window
local function update_error_window(content, opts)
  opts = opts or {}

  -- If window exists and is valid, just update content
  if state.error_win and vim.api.nvim_win_is_valid(state.error_win) then
    if state.error_buf and vim.api.nvim_buf_is_valid(state.error_buf) then
      vim.api.nvim_buf_set_lines(state.error_buf, 0, -1, false, content)
      return
    end
  end

  -- Create new buffer if needed
  if not state.error_buf or not vim.api.nvim_buf_is_valid(state.error_buf) then
    state.error_buf = create_error_buffer()
  end

  -- Set content
  vim.api.nvim_buf_set_lines(state.error_buf, 0, -1, false, content)

  -- Calculate height (up to max_height)
  local height = math.min(#content, M.config.max_height)
  height = math.max(height, 1) -- At least one line

  -- Create window
  state.error_win = vim.api.nvim_open_win(state.error_buf, false, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = 80,
    height = height,
    style = "minimal",
    border = "rounded",
  })

  -- Set window options
  vim.api.nvim_win_set_option(state.error_win, "winblend", 0)
  vim.api.nvim_win_set_option(state.error_win, "foldmethod", "manual")
  vim.api.nvim_win_set_option(state.error_win, "conceallevel", 2)
  vim.api.nvim_win_set_option(state.error_win, "concealcursor", "n")
end

-- Close error window if open
local function close_error_window()
  if state.error_win and vim.api.nvim_win_is_valid(state.error_win) then
    vim.api.nvim_win_close(state.error_win, true)
    state.error_win = nil
  end
end

-- Prettify error message using configured patterns
local function prettify_error(message)
  local result = message

  for _, pattern_info in ipairs(M.config.prettify_patterns) do
    result = result:gsub(pattern_info.pattern, pattern_info.replace)
  end

  return M.config.styling.prefix .. result
end

-- Process diagnostics and show window if appropriate
local function process_diagnostics()
  -- If disabled or not on a TS/JS file, ignore
  if not state.enabled then return end

  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  if not (ft == "typescript" or ft == "javascript" or ft == "typescriptreact" or ft == "javascriptreact") then
    return
  end

  -- Get cursor position
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local line = cursor_pos[1] - 1
  local col = cursor_pos[2]

  -- Get diagnostics at cursor position
  local diagnostics = vim.diagnostic.get(bufnr, { lnum = line })

  -- Filter to only get diagnostics at or before cursor column
  local current_diagnostics = {}
  for _, diagnostic in ipairs(diagnostics) do
    if diagnostic.col <= col and (diagnostic.col + diagnostic.end_col) >= col then
      table.insert(current_diagnostics, diagnostic)
    end
  end

  -- If no diagnostics at cursor, close window
  if #current_diagnostics == 0 then
    close_error_window()
    return
  end

  -- Process and display the diagnostic
  local content = {}
  for _, diagnostic in ipairs(current_diagnostics) do
    local prettified = prettify_error(diagnostic.message)
    local lines = vim.split(prettified, "\n")
    for _, line in ipairs(lines) do
      table.insert(content, line)
    end
  end

  update_error_window(content)
end

-- Setup the plugin
function M.setup(opts)
  -- Merge user config with defaults
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Set initial state
  state.enabled = M.config.enabled

  -- Create autocommands
  vim.api.nvim_create_augroup("PrettyTsErrors", { clear = true })

  -- Update on cursor movement
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorHold" }, {
    group = "PrettyTsErrors",
    callback = function()
      process_diagnostics()
    end,
  })

  -- Close window when leaving buffer
  vim.api.nvim_create_autocmd({ "BufLeave", "InsertEnter" }, {
    group = "PrettyTsErrors",
    callback = function()
      close_error_window()
    end,
  })

  -- Toggle command
  vim.api.nvim_create_user_command("PrettyTsErrorsToggle", function()
    state.enabled = not state.enabled
    if not state.enabled then
      close_error_window()
    else
      process_diagnostics()
    end
    print("Pretty TS Errors: " .. (state.enabled and "Enabled" or "Disabled"))
  end, {})

  return M
end

-- Toggle plugin on/off
function M.toggle()
  state.enabled = not state.enabled
  if not state.enabled then
    close_error_window()
  else
    process_diagnostics()
  end
  return state.enabled
end

return M

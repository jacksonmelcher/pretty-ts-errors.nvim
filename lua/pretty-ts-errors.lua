-- pretty-ts-errors.nvim
-- A Neovim plugin to improve TypeScript error messages

local M = {}

-- Default configuration
M.config = {
  -- Whether to enable the plugin by default
  auto_show_on_cursor = false,

  -- Maximum height of the error window
  max_height = 15,

  -- Maximum width of the error window
  max_width = 80,

  -- Whether to show original TS error below the prettified version
  show_original_error = true,

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

  -- Whether to integrate with the LSP diagnostics
  integrate_with_lsp = true,

  -- Keymap configuration
  keymaps = {
    -- Toggle the error window on/off
    toggle = "<leader>te",

    -- Show the error at cursor position
    show_at_cursor = "<leader>se",

    -- Jump to next/previous error
    next_error = "]e",
    prev_error = "[e",
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

    -- Handle missing property errors with improved formatting
    {
      pattern = "Property '([^']+)' is missing in type '(.+)' but required in type '(.+)'",
      replace = "Property $1 is missing in type:\n\n$2\n\nbut required in type:\n\n$3"
    },

    -- Handle complex type mismatch with better formatting
    {
      pattern = "Argument of type '(.+)' is not assignable to parameter of type '(.+)'",
      replace = "Type mismatch:\n\nProvided: $1\n\nExpected: $2"
    },
  },
}

-- Current state
local state = {
  auto_show_on_cursor = false,
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

-- Format complex type definitions for better readability
local function format_type_definition(type_str)
  -- Look for object type patterns like { ... }
  if type_str:match("^%s*{") then
    -- Indent the type definition for better readability
    local lines = {}
    local in_nested = 0
    local current_line = ""

    -- Split the type into lines with proper indentation
    for i = 1, #type_str do
      local char = type_str:sub(i, i)

      if char == "{" then
        in_nested = in_nested + 1
        current_line = current_line .. char
        table.insert(lines, current_line)
        current_line = string.rep("  ", in_nested)
      elseif char == "}" then
        in_nested = in_nested - 1
        if current_line:match("%S") then
          table.insert(lines, current_line)
        end
        current_line = string.rep("  ", in_nested) .. char
      elseif char == ";" then
        current_line = current_line .. char
        table.insert(lines, current_line)
        current_line = string.rep("  ", in_nested)
      elseif char == "," then
        current_line = current_line .. char
        table.insert(lines, current_line)
        current_line = string.rep("  ", in_nested)
      else
        current_line = current_line .. char
      end
    end

    if current_line:match("%S") then
      table.insert(lines, current_line)
    end

    return table.concat(lines, "\n")
  end

  return type_str
end

-- Create or update error window
local function update_error_window(content, opts)
  opts = opts or {}

  -- Format content lines for better display
  local formatted_content = {}
  for _, line in ipairs(content) do
    -- Replace type definitions with formatted versions
    line = line:gsub("(:[%s\n]*)({[^}]+})", function(prefix, type_def)
      return prefix .. "\n" .. format_type_definition(type_def)
    end)

    -- Format with indentation
    if line:match("^%s*Property") or line:match("^%s*Expected") or line:match("^%s*Provided") then
      table.insert(formatted_content, line)
    else
      for sub_line in line:gmatch("([^\n]+)") do
        table.insert(formatted_content, sub_line)
      end
    end
  end

  -- If window exists and is valid, just update content
  if state.error_win and vim.api.nvim_win_is_valid(state.error_win) then
    if state.error_buf and vim.api.nvim_buf_is_valid(state.error_buf) then
      vim.api.nvim_buf_set_lines(state.error_buf, 0, -1, false, formatted_content)
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
  local height = math.min(#formatted_content, M.config.max_height)
  height = math.max(height, 3) -- At least three lines for better readability

  -- Calculate width based on content
  local width = M.config.max_width
  for _, line in ipairs(formatted_content) do
    width = math.max(width, math.min(vim.api.nvim_strwidth(line) + 2, 120))
  end

  -- Create window
  state.error_win = vim.api.nvim_open_win(state.error_buf, false, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
  })

  -- Set window options
  vim.api.nvim_win_set_option(state.error_win, "winblend", 0)
  vim.api.nvim_win_set_option(state.error_win, "foldmethod", "manual")
  vim.api.nvim_win_set_option(state.error_win, "conceallevel", 2)
  vim.api.nvim_win_set_option(state.error_win, "concealcursor", "n")

  -- Set buffer highlights for keywords
  local ns_id = vim.api.nvim_create_namespace("PrettyTsErrors")
  vim.api.nvim_buf_clear_namespace(state.error_buf, ns_id, 0, -1)

  -- Highlight keywords
  for i, line in ipairs(formatted_content) do
    -- Highlight property names
    local prop_start, prop_end = line:find("Property%s+[%w_]+")
    if prop_start then
      vim.api.nvim_buf_add_highlight(state.error_buf, ns_id, "Special", i - 1, prop_start - 1, prop_end)
    end

    -- Highlight type keywords
    local type_keywords = { "string", "number", "boolean", "object", "array", "null", "undefined" }
    for _, keyword in ipairs(type_keywords) do
      local start_idx = 1
      while true do
        local kw_start, kw_end = line:find(keyword, start_idx, true)
        if not kw_start then break end
        vim.api.nvim_buf_add_highlight(state.error_buf, ns_id, "Type", i - 1, kw_start - 1, kw_end)
        start_idx = kw_end + 1
      end
    end

    -- Highlight section headers like "Expected:" "Provided:"
    if line:match("^Expected:") or line:match("^Provided:") or line:match("^%s*Required:") then
      vim.api.nvim_buf_add_highlight(state.error_buf, ns_id, "Title", i - 1, 0, -1)
    end
    -- Highlight "Original TS Error:" text
    if line:match("Original TS Error:") then
      vim.api.nvim_buf_add_highlight(state.error_buf, ns_id, "Comment", i - 1, 0, -1)
    end

    -- Make original error slightly dimmer
    if i > 0 and formatted_content[i - 1] and formatted_content[i - 1]:match("Original TS Error:") then
      vim.api.nvim_buf_add_highlight(state.error_buf, ns_id, "Comment", i - 1, 0, -1)
    end
  end
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
  local original = message

  -- Handle complex type errors - identify object type structures
  if message:match("{%s*[%w_]+%s*:%s*[%w_]+") and message:match("is not assignable") then
    -- Extract the type information
    local type1, type2 = message:match("type%s+'(.-)' is not assignable to.-type%s+'(.-)'")
    if type1 and type2 then
      return "Type mismatch:\n\nProvided:\n" .. format_type_definition(type1) ..
          "\n\nExpected:\n" .. format_type_definition(type2)
    end
  end

  -- Check for property missing errors
  if message:match("Property '.-' is missing") then
    local prop, type1, type2 = message:match("Property '(.-)' is missing in type '(.-)' but required in type '(.-)'")
    if prop and type1 and type2 then
      return "Property " .. prop .. " is missing in type:\n\n" ..
          format_type_definition(type1) ..
          "\n\nbut required in type:\n\n" ..
          format_type_definition(type2)
    end
  end

  -- Apply configured patterns
  for _, pattern_info in ipairs(M.config.prettify_patterns) do
    result = result:gsub(pattern_info.pattern, pattern_info.replace)
  end

  result = M.config.styling.prefix .. result

  -- Add the original error if configured
  if M.config.show_original_error then
    result = result .. "\n\n---\n*Original TS Error:*\n" .. original
  end

  return result
end

-- Process diagnostics and show window if appropriate
local function process_diagnostics()
  -- If disabled or not on a TS/JS file, ignore
  if not state.auto_show_on_cursor then return end

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
    -- Get the prettified error
    local prettified = prettify_error(diagnostic.message)

    -- Add the prettified error to content
    for _, line in ipairs(vim.split(prettified, "\n")) do
      table.insert(content, line)
    end

    -- If original errors should be shown, append it
    if M.config.show_original_error then
      -- Add a separator
      table.insert(content, "---")
      table.insert(content, "Original TS Error:")

      -- Add the original error line by line
      for _, line in ipairs(vim.split(diagnostic.message, "\n")) do
        table.insert(content, line)
      end
    end
  end

  update_error_window(content)
end

-- Setup the plugin
function M.setup(opts)
  -- Merge user config with defaults
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Set initial state
  state.auto_show_on_cursor = M.config.auto_show_on_cursor

  -- Create autocommands
  vim.api.nvim_create_augroup("PrettyTsErrors", { clear = true })

  -- Add LSP integration if enabled
  if M.config.integrate_with_lsp ~= false then
    M.setup_lsp_integration()
  end
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
    state.auto_show_on_cursor = not state.auto_show_on_cursor
    if not state.auto_show_on_cursor then
      close_error_window()
    else
      process_diagnostics()
    end
    print("Pretty TS Errors: " .. (state.auto_show_on_cursor and "Enabled" or "Disabled"))
  end, {})

  -- Format complex types
  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = "PrettyTsErrors",
    callback = function()
      if state.auto_show_on_cursor then
        vim.defer_fn(process_diagnostics, 100)
      end
    end,
  })

  return M
end

-- Function to integrate with the LSP diagnostic handler
function M.setup_lsp_integration()
  -- Store the original handler
  local original_handler = vim.lsp.handlers["textDocument/publishDiagnostics"]

  -- Override the handler
  vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
    local client = vim.lsp.get_client_by_id(ctx.client_id)

    -- Only modify TypeScript/JavaScript diagnostics
    if client and (client.name == "tsserver" or client.name == "typescript-language-server") then
      if result and result.diagnostics then
        for _, diagnostic in ipairs(result.diagnostics) do
          -- Store the original message
          local original_message = diagnostic.message

          -- Get prettified message
          local prettified = prettify_error(diagnostic.message)

          -- Append original if configured to show it
          if M.config.show_original_error then
            diagnostic.message = prettified .. "\n\n--- Original TS Error ---\n" .. original_message
          else
            diagnostic.message = prettified
          end
        end
      end
    end

    -- Call the original handler with modified diagnostics
    return original_handler(err, result, ctx, config)
  end
end

-- Toggle plugin on/off
function M.toggle()
  state.auto_show_on_cursor = not state.auto_show_on_cursor
  if not state.auto_show_on_cursor then
    close_error_window()
  else
    process_diagnostics()
  end
  return state.auto_show_on_cursor
end

return M

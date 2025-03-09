# pretty-ts-errors.nvim

A Neovim plugin that enhances TypeScript error messages to make them more readable and understandable. Inspired by the VSCode extension [pretty-ts-errors](https://github.com/yoavbls/pretty-ts-errors).

## Features

- Simplifies complex TypeScript error messages
- Shows error explanations in a floating window near the cursor
- Customizable styling and behavior
- Works with TypeScript, JavaScript, TSX, and JSX files

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
return {
  "jackson-melcher/pretty-ts-errors.nvim",
  ft = { "typescript", "javascript", "typescriptreact", "javascriptreact" },
  opts = {
    -- Your configuration options here (optional)
  },
}
```

## Configuration

Here's the default configuration:

```lua
require("pretty-ts-errors").setup({
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
    { pattern = "Type '(.+)' is not assignable to type '(.+)'", 
      replace = "Expected type '$2', but got '$1'" },
    
    -- Simplify property errors
    { pattern = "Property '(.+)' does not exist on type '(.+)'", 
      replace = "The object '$2' doesn't have a property named '$1'" },
    
    -- Simplify missing parameters 
    { pattern = "Expected (%d+) arguments, but got (%d+)", 
      replace = "This function takes $1 parameters, but you provided $2" },
  },
})
```

## Usage

The plugin works automatically when you move your cursor over TypeScript errors in supported file types.

### Commands

- `:PrettyTsErrorsToggle` - Toggle the plugin on/off

## Adding More Error Patterns

You can add your own error patterns to simplify by adding them to the `prettify_patterns` configuration:

```lua
require("pretty-ts-errors").setup({
  prettify_patterns = {
    -- Your custom patterns
    { pattern = "Cannot find name '(.+)'", 
      replace = "The variable '$1' doesn't exist in this scope" },
    
    -- Plus the default patterns
    { pattern = "Type '(.+)' is not assignable to type '(.+)'", 
      replace = "Expected type '$2', but got '$1'" },
    -- ... other default patterns
  },
})
```

## License
MIT

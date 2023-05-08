# nvim-utility-lib.nvim

A collection of somewhat random helper functions nvim. Especially related to
error / warning / diagnostic navigation.

Example usage:

```lua
local util = require('nvim-utility-lib')
util.toggle_quickfix()
```

Available functions:

| Function                           | Description |
| ---------------------------------- | ----------- |
| `extended_home()`                  | Extended home key (first press uses whitespace, second press goes to column 1). |
| `toggle_quickfix()`                | Toggles the quickfix window. |
| `goto_next_diagnostic(name, opts)` | Goes to the next diagnostic globally. `name` is used for notifications messages. `opts` is used to filter diagnostics according to `vim.diagnostic.get()`. Both arguments are optional. |
| `goto_prev_diagnostic(name, opts)` | Same as `goto_next_diagnostic(name, opts)` but in the reverse order. |
| `goto_next_error()`                | Goes to the next error globally. |
| `goto_prev_error()`                | Goes to the previous error globally. |
| `goto_next_warning()`              | Goes to the next warning or error globally. |
| `goto_prev_warning()`              | Goes to the previous warning or error globally. |
| `goto_next_only_warning()`         | Goes to the next warning globally. |
| `goto_prev_only_warning()`         | Goes to the previous warning globally. |
| `overseer_message()`               | Gets the last output line from the currently running overseer task. |
| `overseer_has_task(name)`          | Determines if there is an overseer task with the given name. |
| `overseer_find_task(names)`        | Returns the first task from the list that was found. |
| `overseer_run_first_of(names)`     | Runs the first task that is found in the provided list. |

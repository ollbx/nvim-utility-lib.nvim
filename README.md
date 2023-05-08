# nvim-utility-lib.nvim

A collection of somewhat random helper functions nvim. Especially related to
error / warning / diagnostic navigation.

Example usage:

```lua
local util = require('nvim-utility-lib')
util.toggle_quickfix()
```

Available functions:

| Function            | Description |
| ------------------- | ----------- |
| `extended_home()`   | Extended home key (first press uses whitespace, second press goes to column 1). |
| `toggle_quickfix()` | Toggles the quickfix window. |

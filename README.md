# build-helpers.nvim

A collection of helper functions for error / warning / diagnostic navigation
and build related tasks.

Example usage:

```lua
local build_helpers = require('build-helpers')
build_helpers.toggle_quickfix()
```

Available functions:

| Function            | Description |
| ------------------- | ----------- |
| `toggle_quickfix()` | Toggles the quickfix window. |

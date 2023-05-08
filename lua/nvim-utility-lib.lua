local M = {}

-- Extended home key functionality. The first key press will go to the start
-- of the line, while respecting indentation (like `^`). The second key press
-- will go to the first column (like `0`).
function M.extended_home()
	local _, old_col = unpack(vim.api.nvim_win_get_cursor(0))
	vim.cmd('normal! ^')
	local _, new_col = unpack(vim.api.nvim_win_get_cursor(0))
	if old_col == new_col then
		vim.cmd('normal! 0')
	end
end

-- Toggles the quickfix list on the bottom of the screen.
function M.toggle_quickfix()
	local exists = false

	for _, win in pairs(vim.fn.getwininfo()) do
		if win["quickfix"] == 1 then
			exists = true
			break
		end
	end

	if exists == true then
		vim.cmd("cclose")
	else
		vim.cmd("bo copen")
	end
end

local function try_require(name)
	local success, mod = pcall(require, name)
	if success then
		return mod
	end
	return nil
end

-- Returns the last output from the currently running overseer task.
function M.overseer_message()
	local overseer = try_require("overseer")

	if overseer then
		local task_list = require("overseer.task_list")

		local tasks = task_list.list_tasks({
			status = overseer.STATUS.RUNNING
		})

		local task = tasks[1]

		if task == nil or task.components == nil then
			return ""
		end

		for _,component in ipairs(task.components) do
			if component.name == "on_output_summarize" then
				local lines = component.lines
				local line = lines[#lines]

				if line == nil then
					return ""
				else
					return line
				end
			end
		end
	end

	return ""
end

-- Runs the first task from a list of tasks.
function M.overseer_run_first(names)
	local overseer = try_require("overseer")
	local template = try_require("overseer.template")

	if overseer and template then
		local opts = { dir = vim.fn.getcwd() }

		-- This is async with a completion CB.
		template.list(opts, function(templates)
			-- Collect the names of all templates.
			local found_names = {}

			for _, tmpl in ipairs(templates) do
				table.insert(found_names, tmpl.name)
			end

			-- Find the first matching name.
			for _, name in ipairs(names) do
				if found_names:contains(name) then
					-- Run the template and abort.
					overseer.run_template({ name = name })
					return
				end
			end

			vim.notify("no task found", vim.log.levels.ERROR)
		end)
	end
end

local function location_less(a, b)
	if a[1] == b[1] then
		if a[2] == b[2] then
			return a[3] < b[3]
		end
		return a[2] < b[2]
	end
	return a[1] < b[1]
end

local function location_line_less(a, b)
	if a[1] == b[1] then
		return a[2] < b[2]
	end
	return a[1] < b[1]
end

local function location_goto(loc)
	vim.api.nvim_win_set_buf(0, loc[1]);
	vim.api.nvim_win_set_cursor(0, { loc[2], loc[3] })

	vim.schedule(function()
		vim.diagnostic.open_float({
			focus = false
		})
	end)
end

local function is_same_line(a, b)
	return a[1] == b[1] and a[2] == b[2]
end

-- Returns the current cursor position as a location object.
function M.get_cursor_location()
	local bufnr = vim.api.nvim_win_get_buf(0)
	local cursor = vim.api.nvim_win_get_cursor(0)
	return { bufnr, cursor[1], cursor[2] }
end

local function notify_goto(type, index, count)
	vim.notify('goto '..type..' '..index..'/'..count, vim.log.levels.INFO)
end

-- Retrieves the sorted and deduplicated locations of all diagnostics.
function M.get_diagnostic_locations(opts)
	-- First create locations for all diagnostics.
	local locations = {}

	for _,diagnostic in ipairs(vim.diagnostic.get(nil, opts)) do
		if not vim.diagnostic.is_disabled(0, diagnostic.namespace) then
			table.insert(locations, { diagnostic.bufnr, diagnostic.lnum + 1, diagnostic.col })
		end
	end

	-- Then sort them by the location ID.
	table.sort(locations, location_less)

	-- Then only keep one diagnostic per line.
	local last = nil
	local result = {}

	for _,location in ipairs(locations) do
		if last == nil or not is_same_line(location, last) then
			table.insert(result, location)
			last = location
		end
	end

	return result
end

-- Goes to the next diagnostic globally.
function M.goto_next_diagnostic(name, opts)
	name = name or "diagnostic"
	opts = opts or {}

	local locations = M.get_diagnostic_locations(opts)
	local cursor = M.get_cursor_location()

	for i,location in ipairs(locations) do
		if location_line_less(cursor, location) then
			notify_goto(name, i, #locations)
			location_goto(location)
			return
		end
	end

	local first = locations[1]
	if first ~= nil then
		notify_goto(name, 1, #locations)
		location_goto(first)
	else
		vim.notify('no '..name..' found', vim.log.levels.WARN)
	end
end

-- Goes to the previous diagnostic globally.
function M.goto_prev_diagnostic(name, opts)
	name = name or "diagnostic"
	opts = opts or {}

	local locations = M.get_diagnostic_locations(opts)
	local cursor = M.get_cursor_location()

	for i = #locations, 1, -1 do
		local location = locations[i]

		if location_line_less(location, cursor) then
			notify_goto(name, i, #locations)
			location_goto(location)
			return
		end
	end

	local last = locations[#locations]
	if last ~= nil then
		notify_goto(name, #locations, #locations)
		location_goto(last)
	else
		vim.notify('no '..name..' found', vim.log.levels.WARN)
	end
end

-- Goes to the next error (or worse).
function M.goto_next_error()
	M.goto_next_diagnostic("error", {
		severity = { min = vim.diagnostic.severity.ERROR }
	})
end

-- Goes to the previous error (or worse).
function M.goto_prev_error()
	M.goto_prev_diagnostic("error", {
		severity = { min = vim.diagnostic.severity.ERROR }
	})
end

-- Goes to the next warning (or worse).
function M.goto_next_warning()
	M.goto_next_diagnostic("warning", {
		severity = { min = vim.diagnostic.severity.WARN }
	})
end

-- Goes to the previous warning (or worse).
function M.goto_prev_warning()
	M.goto_prev_diagnostic("warning", {
		severity = { min = vim.diagnostic.severity.WARN }
	})
end

-- Goes to the next warning (ignores errors).
function M.goto_next_only_warning()
	M.goto_next_diagnostic("warning", {
		severity = { min = vim.diagnostic.severity.WARN, max = vim.diagnostic.severity.WARN }
	})
end

-- Goes to the previous warning (ignores errors).
function M.goto_prev_only_warning()
	M.goto_prev_diagnostic("warning", {
		severity = { min = vim.diagnostic.severity.WARN, max = vim.diagnostic.severity.WARN }
	})
end

return M

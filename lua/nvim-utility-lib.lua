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
function M.qf_toggle()
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

local qf = {
	info = nil,
	all = nil, -- Full list.
	sel = nil  -- Current selection.
}

-- Collects information about the quickfix buffer / window.
local function qf_info()
	for _, win in pairs(vim.fn.getwininfo()) do
		if win.quickfix == 1 then
			local buf = vim.fn.getbufinfo(win.bufnr)
			local tick = buf[1].changedtick
			local index = vim.fn.getqflist({idx = 0}).idx

			return {
				bufnr = win.bufnr,
				winid = win.winid,
				tick = tick,
				index = index
			}
		end
	end
	return nil
end

-- Updates the cached QF information.
local function qf_update()
	local new_info = qf_info()

	if not new_info then
		return
	end

	-- If the QF content has changed, update data.
	if not qf.info or qf.info.tick ~= new_info.tick then
		qf.all = vim.fn.getqflist()
		qf.sel = nil

		-- Add the index in the "all" list.
		for i, item in ipairs(qf.all) do
			item.all_index = i
		end
	end

	qf.info = new_info
end

-- Removes all lines not matching the errorformat from the quickfix list.
function M.qf_filter()
	-- Return if already filtered.
	if qf.sel then
		return
	end

	qf_update()

	-- Create a new selection.
	local new_index = 1
	qf.sel = {}

	for i, item in ipairs(qf.all) do
		if item.valid == 1 then
			table.insert(qf.sel, item)

			-- Select the added entry if it is below the old selection.
			if i <= qf.info.index then
				new_index = #(qf.sel)
			end
		end
	end

	-- Update the list and cursor position.
	vim.fn.setqflist(qf.sel, 'r')
	vim.fn.setqflist({}, 'a', { idx = new_index })

	-- Update the info to cover the last update.
	qf.info = qf_info()
end

-- Restores the previous quickfix list.
function M.qf_restore()
	qf_update()

	-- Return if not filtered.
	if not qf.sel then
		return
	end

	-- Find the item under the current cursor.
	local cur_item = qf.sel[qf.info.index];

	if not cur_item then
		return
	end

	vim.fn.setqflist(qf.all, 'r')
	vim.fn.setqflist({}, 'a', { idx = cur_item.all_index })

	-- Update the info, reset the selection.
	qf.info = qf_info()
	qf.sel = nil
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
				found_names[tmpl.name] = true
			end

			-- Find the first matching name.
			for _, name in ipairs(names) do
				if found_names[name] ~= nil then
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

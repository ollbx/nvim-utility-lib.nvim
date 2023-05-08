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

return M

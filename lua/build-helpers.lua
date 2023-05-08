local M = {}

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

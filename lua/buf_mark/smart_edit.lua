local M = {}
local util = require("buf_mark.util")

local function get_file_name(full_path)
	return vim.fn.fnamemodify(full_path, ":t")
end

local function get_open_buffer_names()
	local all_bufs = vim.api.nvim_list_bufs()
	local buffer_names = {}
	for _, bufnr in ipairs(all_bufs) do
		if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_get_option(bufnr, "buflisted") then
			local bufname = vim.api.nvim_buf_get_name(bufnr)
			-- Optionally, check if bufname is not empty
			if bufname ~= "" then
				table.insert(buffer_names, get_file_name(bufname))
			end
		end
	end
	return buffer_names
end

-- complete
function M.completion(arglead, cmdline, cursorpos)
	local buffers = nil
	local files = {}

	-- Get all buffers
	buffers = get_open_buffer_names()

	-- Get all files in the current directory
	local dir = vim.fn.getcwd()
	local files_in_dir = vim.fn.glob(dir .. "/*")
	for file in vim.gsplit(files_in_dir, "\n") do
		table.insert(files, vim.fn.fnamemodify(file, ":t"))
	end

	-- Filter buffers and files based on the input
	local suggestions = {}
	for _, buffer in pairs(buffers) do
		if string.match(buffer, arglead) then
			table.insert(suggestions, buffer)
		end
	end
	for _, file in pairs(files) do
		if string.match(file, arglead) then
			table.insert(suggestions, file)
		end
	end

	suggestions = util.remove_duplicates_from_tbl(suggestions)
	return suggestions
end

function M.edit_buffer_init(args, opts)
	local input = args
	local buffers = {}
	local files = {}

	-- Get all buffers
	buffers = get_open_buffer_names()

	-- Get all files in the current directory
	local dir = vim.fn.getcwd()
	local files_in_dir = vim.fn.glob(dir .. "/*")
	for file in vim.gsplit(files_in_dir, "\n") do
		table.insert(files, { path = file, name = vim.fn.fnamemodify(file, ":t") })
	end

	-- Check if the input matches a buffer
	for _, buffer in pairs(buffers) do
		if string.match(buffer:lower(), input:lower()) then
			vim.cmd("buffer " .. buffer)
			return
		end
	end

	-- Check if the input matches a file
	for _, file in pairs(files) do
		if string.match(file.name:lower(), input:lower()) then
			vim.cmd("edit " .. file.path)
			return
		end
	end

	local behaviour = opts.behaviour
	if behaviour == "edit" then
		vim.cmd("e " .. input)
	elseif behaviour == "buffer" then
		vim.cmd("buffer " .. input)
	elseif behaviour == "notify" then
		util.Notify("No buffers or files found.", "warn", "buf_mark")
	end
end

return M

local M = {
	find_fallback = "edit",
	find_method = "rg",
}
local util = require("buf_mark.util")

--------------------------------- HELPER ---------------------------------
--------------------------------------------------------------------------
local firstcall_dir
--- get the working dir
---@param firstcall boolean
---@return string
local function get_wd(firstcall)
	if firstcall or not firstcall_dir then
		firstcall_dir = util.GetProjectRoot() or vim.fn.getcwd()
	end
	return firstcall_dir
end

--- add path to a tbl
---@param tbl string[]
---@param fullpath string
local function add_to_buffile(tbl, fullpath)
	local cwd_lead = get_wd(true)
	local file = string.gsub(fullpath, "^" .. cwd_lead:gsub("[%-%.%+%*%?%^%$%(%)%[%]%{%}]", "%%%1") .. "/", "")
	file = string.gsub(file, vim.loop.os_homedir(), "~")
	if fullpath ~= "" then
		table.insert(tbl, file)
	end
end

--- get files
---@return table
local function get_files()
	local dir = get_wd(true)
	local files_in_dir = {}
	local shell_out = { code = nil, stdout = "" }
	local default_timeout = 100

    if dir == vim.loop.os_homedir() then
    	files_in_dir = vim.v.oldfiles
    elseif vim.fn.executable("rg") == 1 and M.find_method == "rg" then
		shell_out = vim.system({ "rg", "--hidden", "--files" }, { cwd = dir, timeout = default_timeout }):wait()
	elseif vim.fn.executable("fd") == 1 and M.find_method == "fd" then
		shell_out = vim.system({ "fd", "--hidden" }, { cwd = dir, timeout = default_timeout }):wait()
    else
        files_in_dir = vim.fn.glob(dir .. "/**/*", false, true)
	end

	if shell_out and shell_out.code == 124 then
		shell_out = vim.system({ "ls" }, { cwd = dir, timeout = default_timeout }):wait()
	end

	if shell_out and shell_out.code == 0 and shell_out.stdout ~= "" then
		files_in_dir = util.split_string(shell_out.stdout, "\n")
	end

	local files = {}
	if type(files_in_dir) == "table" and #files_in_dir > 0 then
		for _, file in ipairs(files_in_dir) do
			add_to_buffile(files, file)
		end
	end

	return files
end

--- get all buffers
---@return table
local function get_buffers()
	local all_bufs = vim.api.nvim_list_bufs()
	local buffer_names = {}
	for _, bufnr in ipairs(all_bufs) do
		if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_get_option(bufnr, "buflisted") then
			local bufname = vim.api.nvim_buf_get_name(bufnr)
			add_to_buffile(buffer_names, bufname)
		end
	end
	return buffer_names
end

--- accumulate the buffers and files
--- @param arg string
--- @return string[]
local function get_entries(arg)
	local buffers = get_buffers()
	local files = get_files()

	local entries = util.join_arr(buffers, files)
	entries = util.remove_duplicates_from_tbl(entries)

	if #arg then
		if vim.fn.executable("fzf") then
			return util.fzfmatch(entries, { "--tiebreak=index", ("--filter=%s"):format(arg) })
		else
			return vim.fn.matchfuzzy(entries, arg)
		end
	else
		return entries
	end
end

-- complete
---@param arglead string
---@return string[]
function M.get_completion(arglead)
	return get_entries(arglead)
end

--- open the file buffer
---@param arg string
function M.open_entry(arg)
	local entry = get_entries(arg)[1]

	if entry then
		if entry:sub(1, 1) == "~" then
			entry = string.gsub(entry, "~", vim.loop.os_homedir())
		else
			entry = string.format("%s/%s", get_wd(false), entry)
		end
		vim.cmd("e " .. entry)
	else
		if M.find_fallback == "edit" then
			vim.cmd("e " .. arg)
		elseif M.find_fallback == "notify" then
			util.Notify("No such file found.", "warn", "buf_mark")
		end
	end
end

return M

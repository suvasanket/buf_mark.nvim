local M = {}
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
	if fullpath ~= "" then
		table.insert(tbl, file)
	end
end

--- get all files
---@return table
local function get_files()
	local files = {}
	local dir = get_wd(true)
	local files_in_dir = vim.fn.glob(dir .. "/**/*", false, true)
	for _, file in ipairs(files_in_dir) do
		add_to_buffile(files, file)
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
--- @return string[]
local function get_entries()
    local buffers = get_buffers()
    local files = get_files()

    local entries = util.join_arr(buffers, files)
    return util.remove_duplicates_from_tbl(entries)
end

-- complete
function M.completion(arglead)
    local entries = get_entries()
    if #arglead == 0 then
        return entries
    else
        return vim.fn.matchfuzzy(entries, arglead)
    end
end

--- open the file buffer
---@param arg string
---@param config table
function M.edit_buffer_init(arg, config)
	local entries = get_entries()
	local entry = vim.fn.matchfuzzy(entries, arg)[1]

    if not entry then
        if config.find_fallback == "edit" then
            vim.cmd("e " .. arg)
        elseif config.find_fallback == "notify" then
            util.Notify("No such file found.", "warn", "buf_mark")
        end
    else
        entry = string.format("%s/%s", get_wd(false), entry)
        vim.cmd("e " .. entry)
    end
end

return M

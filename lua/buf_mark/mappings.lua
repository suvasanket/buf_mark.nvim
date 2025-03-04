local M = {}
local c = require("buf_mark.caching")
local util = require("buf_mark.util")

M.file_map = {}

local function goto_file(char, filemap)
	local file_path = filemap[char]
	if not file_path then
		vim.notify("No file mapped for key: " .. char, vim.log.levels.WARN)
		return
	end

	vim.cmd("edit " .. file_path)
end

local function set_table_entry(key, value, tbl)
	if type(key) ~= "string" then
		error("key must be a string")
	end
	if type(value) ~= "string" then
		error("value must be a string")
	end

	if tbl == nil then
		tbl = {}
	elseif type(tbl) ~= "table" then
		error("tbl must be a table")
	end

	tbl[key] = value
	return tbl
end

function M.mappings_init()
	vim.keymap.set("n", "'", function()
		local project_name = util.GetProjectRoot()
		if project_name then
			local file_map = c.get_project_keys(project_name)
			local char = vim.fn.getcharstr()

			goto_file(char, file_map)
		else
			return
		end
	end, { noremap = true, silent = true })

	vim.keymap.set("n", "M", function()
		local project_name = util.GetProjectRoot()
		if project_name then
			local char = vim.fn.getcharstr()
			local full_filepath = vim.fn.expand("%:p")

            local file_map = set_table_entry(char, full_filepath, M.file_map)
			c.set_project_keys(project_name, file_map)
			util.echoprint(string.format("[buf_mark]%s: %s", char, vim.fn.expand("%")))
		else
			return
		end
	end)
end

return M

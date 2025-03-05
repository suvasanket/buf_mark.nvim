local M = {}
local c = require("buf_mark.caching")
local util = require("buf_mark.util")

M.file_map = {}

local function goto_file(char, filemap)
	local file_path = filemap[char]
	if not file_path then
		vim.notify("No buffer mapped to key: " .. char, vim.log.levels.WARN)
		return char
	end

	vim.cmd("edit! " .. file_path)
	return false
end

local function set_table_entry(key, value, tbl)
	if tbl == nil then
		tbl = {}
	elseif type(tbl) ~= "table" then
		error("tbl must be a table")
	end

	tbl[key] = value
	return tbl
end

-- initilize mappings
function M.mappings_init(config)
	local mappings = config.mappings

	-- get file_map once then cache it
	vim.api.nvim_create_autocmd("DirChanged", {
		callback = function()
			local project_name = util.GetProjectRoot()
			if project_name then
				M.file_map = c.get_project_keys(project_name)
			end
		end,
	})

	-- jump key
	vim.keymap.set("n", mappings.jump_key, function()
		local project_name = util.GetProjectRoot()
		-- if inside project or not
		if project_name then
			-- if mark in current project or not
			if M.file_map then
				local ok, char = pcall(vim.fn.getcharstr)
				-- if interrupted
				if ok then
					goto_file(char, M.file_map)
					util.inspect(M.file_map)
					util.print_map(char, M.file_map, config.persist_marks)
				end
			else
				print("buf_mark: you should mark something first :)")
				return
			end
		else
			print("buf_mark: sorry, no project detected! :(")
			return
		end
	end, { noremap = true, silent = true })

	-- mark key
	vim.keymap.set("n", mappings.marker_key, function()
		local project_name = util.GetProjectRoot()
		if project_name then
			local char = vim.fn.getcharstr()
			local full_filepath = vim.fn.expand("%:p")

			local file_map = set_table_entry(char, full_filepath, nil)
			c.set_project_keys(project_name, file_map)
			util.echoprint(string.format("[buf_mark] %s: %s", char, vim.fn.expand("%")))
		else
			return
		end
	end, { noremap = true, silent = true })
end

return M

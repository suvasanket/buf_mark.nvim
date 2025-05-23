local M = {}
local c = require("buf_mark.caching")
local util = require("buf_mark.util")

M.file_map = {}

local function goto_file(char, filemap, project_name)
	local file_path = filemap[char]
	if file_path then
		if vim.fn.filereadable(file_path) == 1 then
			vim.cmd("edit! " .. file_path)
		else
			filemap[char] = nil
			c.set_project_keys(project_name, filemap)
			util.Notify("It seems file has been moved or deleted.", "warn", "buf_mark")
		end
	else
		util.Notify("No buffer mapped to key: " .. char, "warn", "buf_mark")
	end
end

local function match_persist_marks(char_array, input_char)
	local matched_chars = ""
	local found = false

	for _, char in ipairs(char_array) do
		if string.lower(char) == string.lower(input_char) then
			matched_chars = matched_chars .. char
			found = true
		end
	end

	if not found then
		return input_char
	end

	return matched_chars
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
	vim.keymap.set({ "n", "x", "o", "s" }, mappings.jump_key, function()
		local project_name = util.GetProjectRoot()
		M.file_map = c.get_project_keys(project_name)
		-- if inside project or not
		if project_name then
			-- if mark in current project or not
			if M.file_map then
				-- util.print_map(nil, M.file_map, config.persist_marks)
				local ok, char = pcall(vim.fn.getcharstr)
				-- if not interrupted
				if ok then
					if char == " " then
						pcall(vim.cmd, "BufMarkList")
						return
					end
					goto_file(char, M.file_map, project_name)
					util.print_map(char, M.file_map, config.persist_marks)
				end
			else
				print("buf_mark: you should mark something first :)")
			end
		end
	end, { noremap = true, silent = true })

	-- mark key
	vim.keymap.set("n", mappings.marker_key, function()
		local project_name = util.GetProjectRoot()
		if project_name then
			local ok, char = pcall(vim.fn.getcharstr)
			if char == " " then
				util.Notify("Please pick a char <Space> cannot be used.", "warn", "buf_mark")
				return
			end
			if ok then
				local full_filepath = vim.fn.expand("%:p")
				char = match_persist_marks(config.persist_marks, char)

				local file_map = set_table_entry(char, full_filepath, nil)
				c.set_project_keys(project_name, file_map)
				util.echoprint(string.format("[buf_mark] %s: %s", char, vim.fn.expand("%")))
			end
		else
			return
		end
	end, { noremap = true, silent = true })
end

return M

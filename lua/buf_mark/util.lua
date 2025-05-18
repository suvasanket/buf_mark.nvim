local M = {}

---@param array string[]
---@param string string
---@return table
function M.remove_str_from_tbl(array, string)
	local new_array = {}
	for i, v in ipairs(array) do
		if v ~= string then
			table.insert(new_array, v)
		end
	end
	return new_array
end

function M.remove_duplicates_from_tbl(array)
	local seen = {}
	local result = {}

	for _, value in ipairs(array) do
		if not seen[value] then
			seen[value] = true
			table.insert(result, value)
		end
	end

	return result
end

function M.GetProjectRoot(markers, path_or_bufnr)
	if require("buf_mark.mappings").Extrafile then
		return require("buf_mark.mappings").Extrafile
	end
	if markers then
		return vim.fs.root(path_or_bufnr or 0, markers) or nil
	end

	local patterns = { ".git", "Makefile", "Cargo.toml", "go.mod", "pom.xml", "build.gradle" }
	local root_fpattern = vim.fs.root(path_or_bufnr or 0, patterns)
	local workspace = vim.lsp.buf.list_workspace_folders()

	if root_fpattern then
		return root_fpattern
	elseif workspace then
		return workspace[#workspace]
	else
		return nil
	end
end

function M.echoprint(str, hl)
	if not hl then
		hl = "MoreMsg"
	end
	vim.api.nvim_echo({ { str, hl } }, true, {})
end

function M.Notify(content, level, title)
	title = title or "Info"

	local level_map = {
		error = vim.log.levels.ERROR,
		warn = vim.log.levels.WARN,
		info = vim.log.levels.INFO,
		debug = vim.log.levels.DEBUG,
		trace = vim.log.levels.TRACE,
	}
	level = level_map[level] or vim.log.levels.INFO
	vim.notify(content, level, { title = title })
end

-- print map
---@param char string
---@param tbl table
---@param ordered_keys table
function M.print_map(char, tbl, ordered_keys)
	if not tbl then
		return
	end
	local result = {}
	local seen_keys = {}
	local separator = " "
	vim.api.nvim_set_hl(0, "BufMarkMapUnmarked", { fg = "#606060" })

	-- add sorted keys
	if ordered_keys then
		for i, key in ipairs(ordered_keys) do
			if tbl[key] ~= nil then -- FIXME some ain't right
				if key == char then
					table.insert(result, { "[" .. key .. "]", "ModeMsg" })
				else
					table.insert(result, { "[" .. key .. "]" })
				end
				seen_keys[key] = true -- Mark this key as processed
			else
				table.insert(result, { "[" .. key .. "]", "BufMarkMapUnmarked" })
			end

			if i < #ordered_keys then
				table.insert(result, { separator, nil }) -- Plain text separator
			end
		end
	end

	-- add any extra keys
	local has_extra_keys = false
	for key, _ in pairs(tbl) do
		if not seen_keys[key] then
			-- Add a separator if this is the first extra key
			if not has_extra_keys then
				table.insert(result, { separator, nil }) -- Separator before extra keys
				has_extra_keys = true
			end

			-- Highlight the current key if it matches `char`
			if key == char then
				table.insert(result, { "[" .. key .. "]", "ModeMsg" })
			else
				table.insert(result, { "[" .. key .. "]" })
			end

			for next_key, _ in pairs(tbl) do
				if not seen_keys[next_key] and next_key ~= key then
					table.insert(result, { separator, nil })
					break
				end
			end
		end
	end

	-- Print the result
	vim.api.nvim_echo(result, false, {})

	-- remove the echo
	vim.api.nvim_create_autocmd("InsertEnter", {
		once = true,
		callback = function()
			vim.api.nvim_echo({ { "" } }, false, {})
		end,
	})
end

function M.relative_path(full_path, short_path)
	if not short_path then
		return full_path
	end
	local rel_path = full_path:match("^" .. vim.pesc(short_path) .. "(.*)$")
	return rel_path and rel_path:gsub("^/", "") or full_path
end

function M.Show_buf_keymaps()
	local bufnr = vim.api.nvim_get_current_buf()
	local modes = { "n", "v", "i", "t" }

	local grouped_keymaps = {}
	for _, mode in ipairs(modes) do
		local maps = vim.api.nvim_buf_get_keymap(bufnr, mode)
		for _, map in ipairs(maps) do
			local key = map.lhs:gsub(" ", "<Space>")
			local desc = map.desc or map.rhs
			if desc then
				desc = desc:gsub("<Cmd>", ""):gsub("<CR>", "")
			else
				desc = "[No Info]"
			end
			if not grouped_keymaps[key] then
				grouped_keymaps[key] = {
					modes = {},
					desc = desc,
				}
			end
			table.insert(grouped_keymaps[key].modes, mode)
		end
	end

	local keymaps = {}
	for key, data in pairs(grouped_keymaps) do
		table.sort(data.modes)
		local modes_l = "[" .. table.concat(data.modes, ", ") .. "]"
		table.insert(keymaps, string.format(" %s  %s 󱦰 %s", modes_l, '"' .. key .. '"', data.desc))
	end

	table.sort(keymaps)

	if #keymaps == 0 then
		return
	end

	local temp_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(temp_buf, 0, -1, false, keymaps)

	-- highlight
	vim.api.nvim_buf_call(temp_buf, function()
		vim.cmd("syntax clear")
		vim.cmd("highlight BoldKey gui=bold cterm=bold")
		vim.cmd('syntax match BoldKey /"\\(.*\\)"/ contains=NONE')
	end)

	-- floating window dimensions and position [ai]
	local fixed_width = 55
	local max_height = 10

	local wrapped_lines = {}
	for _, line in ipairs(keymaps) do
		for i = 1, #line, fixed_width do
			table.insert(wrapped_lines, line:sub(i, i + fixed_width - 1))
		end
	end
	local max_width = 0
	for _, line in ipairs(keymaps) do
		max_width = math.max(max_width, vim.fn.strwidth(line))
	end

	local height = math.min(#wrapped_lines, max_height)
	local width = (max_height > 100) and fixed_width or max_width + 2
	local row = vim.o.lines - height
	local col = vim.o.columns - fixed_width - 2

	local win_opts = {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "single",
	}
	local temp_win = vim.api.nvim_open_win(temp_buf, true, win_opts)
	vim.api.nvim_buf_set_option(temp_buf, "modifiable", false)
	vim.api.nvim_buf_set_keymap(temp_buf, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
end

function M.join_arr(tbl1, tbl2)
	local result = {}
	local seen = {}

	local function addToResult(element)
		if not seen[element] then
			seen[element] = true
			table.insert(result, element)
		end
	end

	for _, value in ipairs(tbl1) do
		addToResult(value)
	end

	for _, value in ipairs(tbl2) do
		addToResult(value)
	end

	return result
end

function M.set_table_entry(key, value, tbl)
	if tbl == nil then
		tbl = {}
	elseif type(tbl) ~= "table" then
		error("tbl must be a table")
	end

	tbl[key] = value
	return tbl
end

return M

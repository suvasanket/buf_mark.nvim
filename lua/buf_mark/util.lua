local M = {}

function M.inspect(var)
	print(vim.inspect(var))
end

function M.GetProjectRoot(markers, path_or_bufnr)
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

function M.UserInput(msg, def)
	local ok, input = pcall(vim.fn.input, msg, def or "")
	if ok then
		return input
	end
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
function M.print_map(char, tbl, ordered_keys)
	local result = {}
	local seen_keys = {}
	local separator = " "

	-- add sorted keys
	if ordered_keys then
		for i, key in ipairs(ordered_keys) do
			if tbl[key] ~= nil then
				if key == char then
					table.insert(result, { "[" .. key .. "]", "ModeMsg" })
				else
					table.insert(result, { "[" .. key .. "]" })
				end
				seen_keys[key] = true -- Mark this key as processed
			else
				table.insert(result, { "[" .. key .. "]", "ErrorMsg" }) -- Highlight missing keys
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

return M

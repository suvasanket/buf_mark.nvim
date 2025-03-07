local M = {}

local c = require("buf_mark.caching")
local util = require("buf_mark.util")
local mappings = require("buf_mark.mappings")

-- Refresh the file mapping table from mappings.file_map or from cache.
local function refresh_file_map_tbl()
	local tbl = mappings.file_map or {}
	if next(tbl) == nil then
		tbl = c.get_project_keys(util.GetProjectRoot()) or {}
	end
	return tbl
end

-- Ordered list of keys to display (each line i corresponds to key_order[i]).
local function getKeys(tbl)
	local keys = {}
	local count = 0
	for key, _ in pairs(tbl) do
		table.insert(keys, key)
		count = count + 1
	end
	return keys, count
end

-- Namespace for virtual text.
local ns_id = vim.api.nvim_create_namespace("bufmarklist_key_ns")

-- Global variables that will be refreshed on every call.
M.file_map_tbl = {}
local mark_order = {}
local height = 0

-- Helper: Update virtual text for each line in buffer.
local function update_virtual_text(buf)
	vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
	for i, key in ipairs(mark_order) do
		local virt_text = { { "[" .. key .. "]", "@attribute" } }
		vim.api.nvim_buf_set_virtual_text(buf, ns_id, i - 1, virt_text, {})
	end
end

-- Helper: Build display lines from M.file_map_tbl using ordered keys.
local function build_lines()
	local lines = {}
    local project_path = util.GetProjectRoot()
	for i, key in ipairs(mark_order) do
        local full_path = M.file_map_tbl[key] or ""
		lines[i] = util.relative_path(full_path, project_path)
	end
	-- Ensure that the buffer has at least 'height' lines.
	for i = #mark_order + 1, height do
		lines[i] = ""
	end
	return lines
end

-- update line mark
local function update_line_mark(buf, new_mark, lnum)
	local old_mark = mark_order[lnum]
	if not old_mark then
		vim.api.nvim_err_writeln("No mark for this line")
		return
	end

	-- Get the current value from the line.
	local old_value = M.file_map_tbl[old_mark]

	-- If new_key already exists, then swap the keys.
	if M.file_map_tbl[new_mark] then
		-- Find the line number where new_key is currently located.
		local other_lnum = nil
		for i, key in ipairs(mark_order) do
			if key == new_mark then
				other_lnum = i
				break
			end
		end

		if not other_lnum then
			-- Should not happen if M.file_map_tbl[new_key] exists.
			vim.api.nvim_err_writeln("Mark '" .. new_mark .. "' exists but cannot find its position.")
			return
		end

		local new_value = M.file_map_tbl[new_mark]
		-- Swap the keys in the table.
		M.file_map_tbl[new_mark] = old_value
		M.file_map_tbl[old_mark] = new_value

		-- Swap the keys in the ordering.
		mark_order[lnum] = new_mark
		mark_order[other_lnum] = old_mark

		vim.api.nvim_out_write(
			string.format("Swapped marks on lines %d and %d: '%s' and '%s'.\n", lnum, other_lnum, new_mark, old_mark)
		)
	else
		-- If the new key doesn't exist, then just update normally.
		M.file_map_tbl[new_mark] = old_value
		M.file_map_tbl[old_mark] = nil
		mark_order[lnum] = new_mark
		vim.api.nvim_out_write(string.format("Updated mark %d: %s changed to %s.\n", lnum, old_mark, new_mark))
	end

	-- Update the virtual text in the buffer.
	update_virtual_text(buf)
end

-- Remove the key (entry) for a given line.
local function remove_line_entry(buf, lnum)
	local rem_key = mark_order[lnum]
	if not rem_key then
		vim.api.nvim_err_writeln("No mark for line " .. lnum)
		return
	end

	M.file_map_tbl[rem_key] = nil

	-- Recalculate key_order and height
	mark_order, height = getKeys(M.file_map_tbl)

	-- Refresh all lines in the buffer.
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, build_lines())
	update_virtual_text(buf)
	vim.api.nvim_out_write(string.format("Mark '%s' removed.\n", rem_key))
end

-- update mark
local function update_mark_key(buf)
	local char = vim.fn.nr2char(vim.fn.getchar())
	local lnum = vim.api.nvim_win_get_cursor(0)[1] -- 1-indexed line number
	update_line_mark(buf, char, lnum)
	return ""
end

-- remove mark
local function remove_mark_key(buf)
	if not vim.api.nvim_buf_get_option(0, "modifiable") then
		vim.bo.modifiable = true
	end
	local lnum = vim.api.nvim_win_get_cursor(0)[1]
	remove_line_entry(buf, lnum)
	vim.bo.modifiable = false
	return ""
end

-- heleper: goto buffer
local function goto_line_entry(lnum)
	local cur_mark = mark_order[lnum]
	if not cur_mark then
		vim.api.nvim_err_writeln("No mark for line " .. lnum)
		return
	end

	local cur_buf = M.file_map_tbl[cur_mark]
	vim.cmd.wincmd("p")
	vim.cmd("e " .. cur_buf)
end

-- goto buffer
local function goto_mark()
	local lnum = vim.api.nvim_win_get_cursor(0)[1]
	goto_line_entry(lnum)
end

-- on_buf_unload: save the current state when the buffer is unloaded.
---@diagnostic disable-next-line: unused-local
function M.on_bufmarkls_buf_unload(buf)
	local project_name = util.GetProjectRoot()
	c.set_project_keys(project_name, M.file_map_tbl)
	mappings.file_map = M.file_map_tbl

	-- remove any prints
	vim.api.nvim_echo({ { "" } }, false, {})
end

-- Open the sign window (values only) using virtual text for the keys.
function M.bufmarkls_window()
	-- Refresh the mapping table every time.
	M.file_map_tbl = refresh_file_map_tbl()

	-- Re-compute the ordering and count.
	mark_order, height = getKeys(M.file_map_tbl)
	if height == 0 then
		vim.api.nvim_err_writeln("Nothing to show try marking something first.")
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	if not buf then
		vim.api.nvim_err_writeln("Failed to create buffer")
		return
	end

	-- Create a bottom split of fixed height based on the number of entries.
	vim.cmd("botright " .. height .. "split")
    vim.cmd("resize 7")
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_option(win, "relativenumber", false)
	vim.api.nvim_win_set_buf(win, buf)

	-- Fill the buffer with built lines from current mapping.
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, build_lines())

	-- Mark our buffer for identification if needed.
	vim.api.nvim_buf_set_var(buf, "is_BufMarkList_window", true)

	-- Set the buffer as unmodifiable.
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)

	-- Attach virtual text to display keys.
	update_virtual_text(buf)

	-- Buffer-local mappings:
	local opts = { noremap = true, silent = true }
	vim.api.nvim_buf_set_keymap(buf, "n", "r", "", {
		callback = function()
			return update_mark_key(buf)
		end,
		noremap = true,
		silent = true,
	})
	vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<cr>", opts)
	vim.api.nvim_buf_set_keymap(buf, "n", "dd", "", {
		callback = function()
			return remove_mark_key(buf)
		end,
		noremap = true,
		silent = true,
	})
	vim.api.nvim_buf_set_keymap(buf, "n", "<cr>", "", {
		callback = function()
			return goto_mark()
		end,
		noremap = true,
		silent = true,
	})

	-- Autocommands
	vim.api.nvim_create_autocmd("BufUnload", {
		buffer = buf,
		callback = function(args)
			M.on_bufmarkls_buf_unload(args.buf)
		end,
	})
end

return M

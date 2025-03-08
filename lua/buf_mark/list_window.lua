local M = {}

local c = require("buf_mark.caching")
local util = require("buf_mark.util")
local mappings = require("buf_mark.mappings")
local echo = function(str)
	vim.api.nvim_echo({ { str, "Comment" } }, false, {})
end

-- Refresh the file mapping table from mappings.file_map or from cache.
local function refresh_file_map_tbl()
	local tbl = mappings.file_map or {}
	if next(tbl) == nil then
		tbl = c.get_project_keys(util.GetProjectRoot()) or {}
	end
	return tbl
end

-- Ordered list of keys to display
local function getKeys(tbl, sortedChars)
	local result = {}
	local seen = {}

	if sortedChars then
		for _, key in ipairs(sortedChars) do
			if tbl[key] ~= nil then
				table.insert(result, key)
				seen[key] = true
			end
		end
	end

	for key, _ in pairs(tbl) do
		if not seen[key] then
			table.insert(result, key)
		end
	end

	local count = #result
	return result, count
end

-- Namespace for virtual text.
local ns_id = vim.api.nvim_create_namespace("bufmarklist_key_ns")

-- Global variables that will be refreshed on every call.
M.file_map_tbl = {}
local mark_order = {}
local height = 0

-- Helper: Update virtual text for each line in buffer.
local function update_virtual_text(buf)
	-- Virtual text is tied to the marks (keys) which remain fixed.
	vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
	for i, key in ipairs(mark_order) do
		local virt_text = { { "[" .. key .. "]", "@attribute" } }
		vim.api.nvim_buf_set_virtual_text(buf, ns_id, i - 1, virt_text, {})
	end
end

-- Helper: Build display lines using the file values in M.file_map_tbl,
-- where the key used is fixed from mark_order.
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

-- update line mark (when replacing a mark with another)
local function update_line_mark(buf, new_mark, lnum)
	local old_mark = mark_order[lnum]
	if not old_mark then
		echo("No mark for this line")
		return
	end

	-- Get the current file for the mark.
	local old_value = M.file_map_tbl[old_mark]

	-- If new_mark exists already (has a file), then swap the values.
	if M.file_map_tbl[new_mark] then
		local other_lnum = nil
		for i, key in ipairs(mark_order) do
			if key == new_mark then
				other_lnum = i
				break
			end
		end

		if not other_lnum then
			echo("Mark '" .. new_mark .. "' exists but cannot find its position.")
			return
		end

		-- Swap only the file values associated with the two marks.
		M.file_map_tbl[new_mark], M.file_map_tbl[old_mark] = old_value, M.file_map_tbl[new_mark]

		echo(string.format("mark exists: therefore mark '%s' swapped with '%s'.", new_mark, old_mark))
	else
		-- Otherwise, we update the file value for the current mark.
		M.file_map_tbl[new_mark] = old_value
		M.file_map_tbl[old_mark] = nil
		-- And update the fixed mark for that line.
		mark_order[lnum] = new_mark
		echo(string.format("Updated mark on line %d: '%s' changed to '%s'.", lnum, old_mark, new_mark))
	end

	-- Refresh virtual text and file lines.
	vim.bo.modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, build_lines())
	vim.bo.modifiable = false
	update_virtual_text(buf)
end

-- Remove mark from a given line.
local function remove_line_entry(buf, lnum)
	local rem_key = mark_order[lnum]
	if not rem_key then
		echo("No mark for line " .. lnum)
		return
	end

	M.file_map_tbl[rem_key] = nil

	-- Recompute mark_order and height.
	mark_order, height = getKeys(M.file_map_tbl)

	-- Update the buffer.
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, build_lines())
	update_virtual_text(buf)
	echo(string.format("Mark '%s' removed.", rem_key))
end

-- update mark key triggered by user input.
local function update_mark_key(buf)
	local char = vim.fn.nr2char(vim.fn.getchar())
	local lnum = vim.api.nvim_win_get_cursor(0)[1]
	update_line_mark(buf, char, lnum)
	return ""
end

-- remove mark triggered by dd mapping.
local function remove_mark_key(buf)
	if not vim.api.nvim_buf_get_option(0, "modifiable") then
		vim.bo.modifiable = true
	end
	local lnum = vim.api.nvim_win_get_cursor(0)[1]
	remove_line_entry(buf, lnum)
	vim.bo.modifiable = false
	return ""
end

-- Helper: jump to file for the given line.
local function open_entry(lnum, type)
	local cur_mark = mark_order[lnum]
	if not cur_mark then
		vim.api.nvim_err_writeln("No mark for line " .. lnum)
		return
	end

	local cur_buf = M.file_map_tbl[cur_mark]
	vim.cmd.wincmd("p")
	if type == "split" then
		vim.cmd.wincmd("s")
	elseif type == "vert" then
		vim.cmd.wincmd("v")
	end
	vim.cmd("e " .. cur_buf)
end

-- goto file for current line.
local function open_entry_in_prevwin()
	local lnum = vim.api.nvim_win_get_cursor(0)[1]
	open_entry(lnum)
end
local function open_entry_in_split()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    open_entry(lnum, "split")
end
local function open_entry_in_vsplit()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    open_entry(lnum, "vert")
end

-- Swap the file values for two lines while leaving the persistent marks intact.
local function swap_line(buf, idx1, idx2)
	if not vim.api.nvim_buf_get_option(0, "modifiable") then
		vim.bo.modifiable = true
	end
	if idx2 < 1 or idx2 > #mark_order then
		vim.api.nvim_err_writeln("Cannot swap: out of bounds")
		return
	end

	-- Get the marks for these lines.
	local key1 = mark_order[idx1]
	local key2 = mark_order[idx2]

	-- Swap the file values for the two keys.
	M.file_map_tbl[key1], M.file_map_tbl[key2] = M.file_map_tbl[key2], M.file_map_tbl[key1]

	-- Refresh the displayed lines.
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, build_lines())
	update_virtual_text(buf)
	vim.bo.modifiable = true
end

-- Move the current line’s file value down (swap with next).
local function move_down(buf)
	local lnum = vim.api.nvim_win_get_cursor(0)[1]
	if lnum >= #mark_order then
		vim.api.nvim_err_writeln("Already at bottom; cannot move down.")
		return ""
	end
	swap_line(buf, lnum, lnum + 1)
	vim.cmd("norm! j")
	return ""
end

-- Move the current line’s file value up (swap with previous).
local function move_up(buf)
	local lnum = vim.api.nvim_win_get_cursor(0)[1]
	if lnum <= 1 then
		vim.api.nvim_err_writeln("Already at top; cannot move up.")
		return ""
	end
	swap_line(buf, lnum, lnum - 1)
	vim.cmd("norm! k")
	return ""
end

-- When the buffer unloads, store the current state.
---@diagnostic disable-next-line: unused-local
function M.on_bufmarkls_buf_unload(buf)
	local project_name = util.GetProjectRoot()
	c.set_project_keys(project_name, M.file_map_tbl)
	mappings.file_map = M.file_map_tbl
	vim.api.nvim_echo({ { "" } }, false, {})
end

-- Open the buffer window.
function M.bufmarkls_window(config)
	-- Refresh the mapping.
	M.file_map_tbl = refresh_file_map_tbl()
	-- The order of marks remains fixed.
	mark_order, height = getKeys(M.file_map_tbl, config.persist_marks)
	if height == 0 then
		vim.api.nvim_err_writeln("Nothing to show; try marking something first.")
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	if not buf then
		vim.api.nvim_err_writeln("Failed to create buffer")
		return
	end

	-- Create a bottom split for the display.
	vim.cmd("botright " .. height .. "split")
	vim.cmd("resize 7")
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_option(win, "relativenumber", false)
	vim.api.nvim_win_set_buf(win, buf)

	-- Fill the buffer with file values according to mark_order.
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, build_lines())

	-- Mark the buffer buffer as a special window.
	vim.api.nvim_buf_set_var(buf, "is_BufMarkList_window", true)

	-- Set buffer options.
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)

	-- Attach the virtual text (marks remain fixed).
	update_virtual_text(buf)

	-- Buffer-local mappings.
	vim.api.nvim_buf_set_keymap(buf, "n", "r", "", {
		callback = function()
			return update_mark_key(buf)
		end,
		noremap = true,
		silent = true,
		desc = "change mark.",
	})
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"q",
		":close<cr>",
		{ noremap = true, silent = true, desc = "close list window." }
	)
	vim.api.nvim_buf_set_keymap(buf, "n", "dd", "", {
		callback = function()
			return remove_mark_key(buf)
		end,
		noremap = true,
		silent = true,
		desc = "delete current entry under-cursor.",
	})
	vim.api.nvim_buf_set_keymap(buf, "n", "<cr>", "", {
		callback = function()
			return open_entry_in_prevwin()
		end,
		noremap = true,
		silent = true,
		desc = "open current entry under-cursor.",
	})
    vim.api.nvim_buf_set_keymap(buf, "n", "<C-v>", "", {
        callback = function()
            return open_entry_in_vsplit()
        end,
        noremap = true,
        silent = true,
        desc = "open current entry in vertical split.",
    })
    vim.api.nvim_buf_set_keymap(buf, "n", "<C-s>", "", {
        callback = function()
            return open_entry_in_split()
        end,
        noremap = true,
        silent = true,
        desc = "open current entry in horizontal split.",
    })
	-- New key mappings for swapping lines:
	vim.api.nvim_buf_set_keymap(buf, "n", "<C-n>", "", {
		callback = function()
			return move_down(buf)
		end,
		noremap = true,
		silent = true,
		desc = "move current entry down.",
	})
	vim.api.nvim_buf_set_keymap(buf, "n", "<C-p>", "", {
		callback = function()
			return move_up(buf)
		end,
		noremap = true,
		silent = true,
		desc = "move current entry up.",
	})
	vim.api.nvim_buf_set_keymap(buf, "n", "g?", "", {
		callback = function()
			return util.Show_buf_keymaps()
		end,
		noremap = true,
		silent = true,
		desc = "show help window.",
	})

	-- Save state on unload.
	vim.api.nvim_create_autocmd("BufUnload", {
		buffer = buf,
		callback = function(args)
			M.on_bufmarkls_buf_unload(args.buf)
		end,
	})
end

return M

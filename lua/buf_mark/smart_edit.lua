local M = {}
local util = require("buf_mark.util")

local function fuzzy_match_metrics(candidate, target)
	local candidate_len = #candidate
	local target_len = #target
	local first_match, last_match = nil, nil
	local j = 1

	for i = 1, candidate_len do
		if j <= target_len and candidate:sub(i, i):lower() == target:sub(j, j):lower() then
			first_match = first_match or i
			last_match = i
			j = j + 1
		end
	end

	if j > target_len then
		return { score = last_match - first_match, first = first_match, len = candidate_len }
	else
		return nil
	end
end

local function is_better(metrics_a, metrics_b)
	-- Prefer lower score (closer matching characters)
	if metrics_a.score < metrics_b.score then
		return true
	elseif metrics_a.score > metrics_b.score then
		return false
	end

	-- If same score, prefer the one with an earlier first match index.
	if metrics_a.first < metrics_b.first then
		return true
	elseif metrics_a.first > metrics_b.first then
		return false
	end

	-- If still tied, prefer candidate with shorter overall length.
	return metrics_a.len < metrics_b.len
end

-- fuzzy finder
local function best_entry(tbl, target)
	local best_candidate = nil
	local best_metrics = nil

	for _, candidate in ipairs(tbl) do
		local metrics = fuzzy_match_metrics(candidate, target)
		if metrics then
			if not best_metrics or is_better(metrics, best_metrics) then
				best_candidate = candidate
				best_metrics = metrics
			end
		end
	end

	return best_candidate
end

local function get_files_and_dirs(path)
	local files_and_dirs = {}
	for entry in vim.fs.dir(path) do
		local entry_path = path .. "/" .. entry
		if vim.fn.filereadable(entry_path) == 1 then
			if vim.fn.isdirectory(entry_path) == 1 then
				-- Add directory
				table.insert(files_and_dirs, entry_path)
			else
				-- Add file
				local perms = vim.fn.getfperm(entry_path)
                local has_ext = entry:match("%.[^%.]+$")
				if has_ext or perms and not string.match(perms, "x") then
					table.insert(files_and_dirs, entry_path)
				end
			end
		end
	end
	return files_and_dirs
end

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
function M.completion(arglead)
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
	local buffers = get_open_buffer_names()
	local files = get_files_and_dirs(".")

	local entries = util.join_arr(buffers, files)
	local entry = best_entry(entries, input)

	if entry then
		vim.cmd("e " .. entry)
	else
		local behaviour = opts.behaviour
		if behaviour == "edit" then
			vim.cmd("e " .. input)
		elseif behaviour == "buffer" then
			vim.cmd("buffer " .. input)
		elseif behaviour == "notify" then
			util.Notify("No buffers or files found.", "warn", "buf_mark")
		end
	end
end

return M

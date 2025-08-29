local M = {}

local util = require("buf_mark.util")
local c = require("buf_mark.caching")
local mappings = require("buf_mark.mappings")
local bm_ls = require("buf_mark.list_window")
local c_edit = require("buf_mark.smart_edit")

local function split_table(data, remove_keys)
	local remove_lookup = {}
	for _, key in ipairs(remove_keys or {}) do
		remove_lookup[key] = true
	end

	local removed_map = {}
	local remaining_keys = {}

	for key, value in pairs(data or {}) do
		if remove_lookup[key] then
			removed_map[key] = value
		else
			table.insert(remaining_keys, key)
		end
	end

	return removed_map, remaining_keys
end

local function print_deleted(array)
	local result = {}
	for i, item in ipairs(array) do
		if type(item) ~= "string" then
			error("All elements in the array must be strings")
		end
		table.insert(result, { item, "MoreMsg" })
		if i < #array then
			table.insert(result, { " ", nil })
		end
	end

	table.insert(result, { " mark removed!", nil })
	vim.api.nvim_echo(result, false, {})
end

-- helper for remove projects
local function select_project_remove(project_tbl, all_projects)
	vim.ui.select(project_tbl, { prompt = "Select project to remove:" }, function(selected)
		if selected then
			all_projects[selected] = nil
			c.cache_data(all_projects)
			select_project_remove(util.remove_str_from_tbl(project_tbl, selected), all_projects)
		else
			return
		end
	end)
end

function M.usercmd_init(config)
	-- delete marks
	vim.api.nvim_create_user_command("BMDelete", function(args)
		local args_table = vim.split(args.args, "%s+")
		local project_name = util.GetProjectRoot()

		if args.bang then
			if project_name then
				local project_keys = c.get_project_keys(project_name)
				local kept, remove = split_table(project_keys, config.persist_marks)
				-- remove keys
				c.remove_project_keys(project_name, remove)

				-- set local maps
				mappings.file_map = kept

				print("buf_mark: all marks removed except persistant marks!")
			else
				util.Notify("Not inside any project!", "error", "Buf_mark")
			end
		else
			if args.args and #args.args >= 1 then
				if project_name then
					local project_keys = c.get_project_keys(project_name)
					c.remove_project_keys(project_name, args_table)

					-- set local maps
					mappings.file_map = project_keys

					print_deleted(args_table)
				else
					util.Notify("Not inside any project!", "error", "Buf_mark")
				end
			else
				util.echoprint("Must provide at least one arg", "ErrorMsg")
			end
		end
	end, {
		nargs = "*",
		bang = true,
	})

	-- bufmark add extra mark
	vim.api.nvim_create_user_command("BMAddExtra", function(opts)
		local project_tbl = {}
		local mark = opts.fargs[1]
		local all_projects = require("buf_mark.caching").projects_data
		if not all_projects then
			return
		end

		for key, _ in pairs(all_projects) do
			table.insert(project_tbl, key)
		end

		vim.ui.select(project_tbl, { prompt = "Select the project:" }, function(selected)
			if selected then
				local full_filepath = vim.fn.expand("%:p")

				local file_map = util.set_table_entry(mark, full_filepath, nil)
				c.set_project_keys(selected, file_map)
				util.echoprint(string.format("[buf_mark] %s: %s", mark, vim.fn.expand("%")))
			end
		end)
	end, { desc = "add extra mark to a project", nargs = 1 })

	-- bufmark list
	vim.api.nvim_create_user_command("BMList", function()
		bm_ls.bufmarkls_window(config)
	end, { desc = "open bufmark list" })

	-- remove project
	vim.api.nvim_create_user_command("BMRemoveProject", function()
		local all_projects = require("buf_mark.caching").projects_data
		if not all_projects then
			return
		end

		local project_tbl = {}
		for key, _ in pairs(all_projects) do
			table.insert(project_tbl, key)
		end

		select_project_remove(project_tbl, all_projects)
	end, { desc = "BufMark remove projects" })

	-- custom edit
	vim.api.nvim_create_user_command("Find", function(opts)
		c_edit.edit_buffer_init(opts.args, config)
	end, { nargs = 1, complete = c_edit.completion })
end

return M

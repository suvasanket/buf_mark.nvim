local M = {}
local util = require("buf_mark.util")
local c = require("buf_mark.caching")
local mappings = require("buf_mark.mappings")
local bm_ls = require("buf_mark.list_window")

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

function M.usercmd_init(config)
	-- delete marks
	vim.api.nvim_create_user_command("BufMarkDelete", function(args)
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

	-- bufmark list
    vim.api.nvim_create_user_command("BufMarkList", function()
        bm_ls.bufmarkls_window(config)
        vim.api.nvim_echo({ { "press g? to see all available keymaps.", "Comment" } }, false, {})
    end, { desc = "open bufmark list" })
end

return M

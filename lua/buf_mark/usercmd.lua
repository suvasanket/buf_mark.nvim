local M = {}
local util = require("buf_mark.util")
local c = require("buf_mark.caching")
local mappings = require("buf_mark.mappings")

local function remove_keys_from_table(keys_to_remove, tbl)
	for _, key in ipairs(keys_to_remove) do
		if type(key) ~= "string" then
			error("All elements in the first argument must be strings")
		end
		if tbl[key] ~= nil then
			tbl[key] = nil -- Remove the key by setting it to nil
		end
	end

	return tbl
end
local function filter_table(allowed, tbl)
    local allowed_lookup = {}
    for _, key in ipairs(allowed) do
        allowed_lookup[key] = true
    end

    local new_tbl = {}
    for key, value in pairs(tbl) do
        if allowed_lookup[key] then
            new_tbl[key] = value
        end
    end

    return new_tbl
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

		if args.bang then
            local project_name = util.GetProjectRoot()
            if project_name then
                local project_keys = c.get_project_keys(project_name)
                project_keys = filter_table(config.persist_marks, project_keys) -- remove the marks
                c.set_project_keys(project_name, project_keys)

                -- set local maps
                mappings.file_map = project_keys

                print("buf_mark: all marks removed except persistant marks!")
            else
                util.Notify("Not inside any project!", "error", "Buf_mark")
            end
		else
			if args.args and #args.args >= 1 then
				local project_name = util.GetProjectRoot()
				if project_name then
					local project_keys = c.get_project_keys(project_name)
					project_keys = remove_keys_from_table(args_table, project_keys) -- remove the marks
					c.set_project_keys(project_name, project_keys)

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
end

return M

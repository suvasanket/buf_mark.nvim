local M = {}

local util = require("buf_mark.util")
local data_dir = vim.fn.stdpath("data")
local json_file = data_dir .. "/buf_mark/buf_mark.json"

local function read_file(filepath)
	local file = io.open(filepath, "r")
	if not file then
		return nil, "Cannot open file: " .. filepath
	end
	local content = file:read("*a")
	file:close()
	return content
end

-- ensure file exist
local function ensure_path_exists(filepath)
	-- Extract the directory part of the path
	local dir = vim.fn.fnamemodify(filepath, ":h") -- Directory path
	-- local file = vim.fn.fnamemodify(filepath, ":t") -- File name

	-- Check if the directory exists
	if vim.fn.isdirectory(dir) == 0 then
		-- Create the directory (including parent directories if necessary)
		vim.fn.mkdir(dir, "p")
	end

	-- Check if the file exists
	if vim.fn.filereadable(filepath) == 0 then
		-- Create the file
		local f = io.open(filepath, "w")
		if f then
			f:write("{}") -- Write `{}` as the default JSON content
			f:close()
		else
			return nil, "Failed to create file"
		end
	end

	return true
end

-- Function to load JSON and decode it into a Lua table
---@param name string|nil
---@return any
function M.load_json(name)
	local json_path = json_file
	if name then
		json_path = ("%s/buf_mark/%s.json"):format(data_dir, name)
	end
	-- Ensure the file exists
	local exists, err_exist = ensure_path_exists(json_path)
	if not exists then
		util.Notify("Error ensuring file exists: " .. err_exist, "error", "Buf_mark")
		return nil
	end

	-- Read the file content
	local content, err = read_file(json_path)
	if not content then
		util.Notify("Error reading file: " .. err, "error", "Buf_mark")
		return nil
	end

	local ok, data = pcall(vim.fn.json_decode, content)
	if not ok then
		util.Notify("Error decoding JSON: " .. data, "error", "Buf_mark")
		return nil
	end

	return data
end

-- Utility function to write content to a file
local function write_file(filepath, content)
	local file = io.open(filepath, "w")
	if not file then
		return false, "Cannot open file for writing: " .. filepath
	end
	file:write(content)
	file:close()
	return true
end

-- Function to save JSON data (Lua table) to a file
---@param data any
---@param opts {json: string}|nil
---@return boolean
function M.cache_data(data, opts)
	local ok, json_str = pcall(vim.fn.json_encode, data)
	if not ok then
		util.Notify("Error encoding JSON: " .. json_str, "error", "Buf_mark")
		return false
	end

	local json_path = json_file
	if opts and opts.json then
		json_path = ("%s/buf_mark/%s.json"):format(data_dir, opts.json)
	end

	local success, err = write_file(json_path, json_str)
	if not success then
		util.Notify("Error writing file: " .. err, "error", "Buf_mark")
		return false
	end

	return true
end

-- Path to your JSON file containing projects.
M.projects_data = M.load_json()
if not M.projects_data then
	util.Notify("Failed to load projects!", "error", "Buf_mark")
	return
end

-- get keys
function M.get_project_keys(project_name)
	local project = M.projects_data[project_name]
	if not project then
		return nil
	end
	return project
end

-- set keys
function M.set_project_keys(project_name, new_keys)
	-- If the project does not exist, create a new table for it.
	if not M.projects_data[project_name] then
		M.projects_data[project_name] = {}
	end

	local project = M.projects_data[project_name]
	-- Loop through each key in new_keys and update the project.
	for k, v in pairs(new_keys) do
		project[k] = v
	end

	-- Save the updated projects_data back to the JSON file.
	local ret = M.cache_data(M.projects_data)
	if not ret then
		util.Notify("Failed to update project '" .. project_name .. "'!", "error", "Buf_mark")
	end
end

-- remove project keys
function M.remove_project_keys(project_name, keys)
	if not M.projects_data[project_name] then
		return nil
	end
	local project = M.projects_data[project_name]
	for _, i in ipairs(keys) do
		project[i] = nil
	end

	local ret = M.cache_data(M.projects_data)
	if not ret then
		util.Notify("Failed to update project '" .. project_name .. "'!", "error", "Buf_mark")
	end
end

return M

local M = {}

local util = require("buf_mark.util")
local json_file = vim.fn.expand("~/codes/projects/buf_mark-nvim/lua/buf_mark/some.json")

local function read_file(filepath)
	local file = io.open(filepath, "r")
	if not file then
		return nil, "Cannot open file: " .. filepath
	end
	local content = file:read("*a")
	file:close()
	return content
end

-- Function to load JSON and decode it into a Lua table
local function load_json(filepath)
	local content, err = read_file(filepath)
	if not content then
		print("Error reading file: " .. err)
		return nil
	end

	local ok, data = pcall(vim.fn.json_decode, content)
	if not ok then
		print("Error decoding JSON: " .. data)
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
local function save_json(filepath, data)
	local ok, json_str = pcall(vim.fn.json_encode, data)
	if not ok then
		print("Error encoding JSON: " .. json_str)
		return false
	end

	local success, err = write_file(filepath, json_str)
	if not success then
		print("Error writing file: " .. err)
		return false
	end

	return true
end

-- Path to your JSON file containing projects.
local projects_data = load_json(json_file)
if not projects_data then
	print("Failed to load projects!")
	return
end

-- Function to get specified keys for a given project.
-- keys should be an array of key names you want to retrieve.
function M.get_project_keys(project_name)
	local project = projects_data[project_name]
	if not project then
		print("Project '" .. project_name .. "' not found!")
		return nil
	end
	return project
end

-- Function to set/update any keys for a specific project.
-- new_keys is a table where keys are the property names and the values are their new values.
function M.set_project_keys(project_name, new_keys)
	-- If the project does not exist, create a new table for it.
	if not projects_data[project_name] then
		projects_data[project_name] = {}
	end

	local project = projects_data[project_name]
	-- Loop through each key in new_keys and update the project.
	for k, v in pairs(new_keys) do
		project[k] = v
	end

	-- Save the updated projects_data back to the JSON file.
	local ret = save_json(json_file, projects_data)
	if ret then
		print("Project '" .. project_name .. "' updated successfully!")
	else
		print("Failed to update project '" .. project_name .. "'!")
	end
end

return M

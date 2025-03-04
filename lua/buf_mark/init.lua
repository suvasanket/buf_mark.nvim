local M = {}

local defaults = {
	mappings = {
		jump_key = "'",
		marker_key = "M",
	},
}

function M.setup(opts)
	opts = opts or {}
	M.config = vim.tbl_deep_extend("force", defaults, opts)

	-- Initialize mappings
	require("buf_mark.mappings").mappings_init(M.config.mappings)
end

return M

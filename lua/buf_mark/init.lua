local M = {}

local defaults = {
	mappings = {
		jump_key = "'",
		marker_key = "M",
	},
	persist_marks = { "a", "s", "d", "f" },
    find_fallback = 'notify', -- |edit, notify|
}

function M.setup(opts)
	opts = opts or {}
	M.config = vim.tbl_deep_extend("force", defaults, opts)

	-- Initialize mappings
	require("buf_mark.mappings").mappings_init(M.config)

	-- Initialize usercmd
	require("buf_mark.usercmd").usercmd_init(M.config)
end

return M

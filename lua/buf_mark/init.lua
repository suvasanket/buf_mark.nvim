local M = {}

local defaults = {
    jump_key = "<cr>",
    marker_key = "<leader>'"
}

function M.setup(opts)
    opts = opts or {}
    M.config = vim.tbl_deep_extend("force", defaults, opts)

    require("buf_mark.mappings").mappings_init()
end

return M

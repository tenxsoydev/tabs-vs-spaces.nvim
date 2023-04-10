--[[ tabs-vs-spaces.nvim
Source: https://github.com/tenxsoydev/tabs-vs-spaces.nvim
License: MIT
]]

local M = {}

local PLUGIN = "tabs_vs_spaces"
local CLUSTER = "TabsVsSpaces"

-- Types ======================================================================

---@class Config
---@field indentation "auto"|"tabs"|"spaces"
---@field match_priority number
---@field highlight string|table
---@field ignore { filetypes: string[], buftypes: string[] }
---@field standartize_on_save boolean
---@field user_commands boolean

---@alias Indentaiton "tabs"|"spaces"

-- Config =====================================================================

---@type Config
local config = {
	indentation = "auto",
	highlight = "DiagnosticUnderlineHint",
	priority = 20,
	ignore = {
		filetypes = {},
		buftypes = {
			"acwrite",
			"help",
			"nofile",
			"nowrite",
			"quickfix",
			"terminal",
			"prompt",
		},
	},
	standartize_on_save = false,
	user_commands = true,
}

-- Utils ======================================================================

local api, fn = vim.api, vim.fn
---@type Indentaiton
local current_deviator
---@type { string: boolean }, { string: boolean }
local ignored_ft, ignored_bt = {}, {}
-- Plugins that potentially interfere
local has_indent_bl = pcall(require, "indent_blankline")
local has_tint, tint = pcall(require, "tint")

local function set_ignored()
	for _, key in ipairs(config.ignore.filetypes) do
		ignored_ft[key] = true
	end
	for _, key in ipairs(config.ignore.buftypes) do
		ignored_bt[key] = true
	end
end

---@return number?
local function get_match_id()
	local match = vim.tbl_filter(function(m) return m.group == "TabsVsSpaces" end, vim.fn.getmatches())[1]
	if match then fn.matchdelete(match.id) end
end

---@return Indentaiton
local function get_denominator()
	local space_num, tab_num = 0, 0
	for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
		if line:match("^ +") then space_num = space_num + 1 end
		if line:match("^\t+") then tab_num = tab_num + 1 end
	end

	return space_num > tab_num and "spaces" or "tabs"
end

-- Highlight ==================================================================

local function set_hl()
	if type(config.highlight) == "string" then
		api.nvim_set_hl(0, CLUSTER, { link = config.highlight })
		return
	end
	-- type-check: "string" is handled above
	api.nvim_set_hl(0, CLUSTER, config.highlight)
end

local function clear_hl(buf)
	local match = get_match_id()
	if match then fn.matchdelete(match.id) end
	if not buf then api.nvim_set_hl(0, CLUSTER, {}) end
end

---@param indentation Indentaiton
local function add_matches(indentation)
	local pattern = [[\(^\s*\)\@<= \+]] -- Space indent
	if indentation == "tabs" and current_deviator == "tabs" then clear_hl() end
	if indentation == "spaces" then
		pattern = [[\(^\s*\)\@<=\t\+]] -- Tab indent
		if current_deviator == "spaces" then clear_hl() end
	end

	if get_match_id() then return end

	fn.matchadd(CLUSTER, pattern, config.priority)
	-- IndentBlanklineSpaceChar interferes with highlighting of indentaiton
	if has_indent_bl then api.nvim_set_hl(0, "IndentBlanklineSpaceChar", {}) end

	current_deviator = indentation == "spaces" and "tabs" or "spaces"
end

---@param enable? boolean @treated as `true` if not set
---@param buf? boolean
function M.highlight(enable, buf)
	enable = enable == nil and true or enable

	if
		not enable
		or ignored_ft[vim.bo.filetype]
		or ignored_bt[vim.bo.buftype]
		or vim.g[PLUGIN] == 0
		or vim.b[PLUGIN] == 0
	then
		clear_hl(buf)
		return
	end

	if config.indentation == "auto" then
		add_matches(get_denominator())
	else
		-- type-check: "auto" is handled above
		add_matches(config.indentation)
	end

	set_hl()
end

-- Auto Commands ==============================================================

local function create_aus()
	api.nvim_create_augroup(CLUSTER, { clear = true })
	api.nvim_create_autocmd({ "WinEnter", "BufEnter", "CmdlineLeave", "BufWritePost" }, {
		group = CLUSTER,
		callback = function() vim.schedule(M.highlight) end,
	})
	if not config.standartize_on_save then return end
	api.nvim_create_autocmd("BufWritePre", {
		group = CLUSTER,
		callback = M.standartize,
	})
end

-- User Commands ==============================================================

---@param buf? boolean
local function toggle_off(buf)
	M.highlight(false, buf)

	if buf then
		vim.b[PLUGIN] = 0
	else
		vim.g[PLUGIN] = 0
		if fn.exists("#" .. CLUSTER) ~= 0 then api.nvim_del_augroup_by_name(CLUSTER) end
	end
end

---@param buf? boolean
local function toggle_on(buf)
	if buf then
		vim.b[PLUGIN] = 1
	else
		vim.g[PLUGIN] = 1
	end
	create_aus()
	M.highlight(true, buf)
end

---@param enable? boolean
---@param buf? boolean
function M.toggle(enable, buf)
	if not enable then
		toggle_off(buf)
	else
		toggle_on(buf)
	end
	-- Highlighting is not updated in splits when using tint, so we tint.refresh here when it is used.
	if has_tint then tint.refresh() end
end

---@param indentation Indentaiton
---@param range 0|2
function M.convert(indentation, range)
	local ts = vim.bo.tabstop
	if indentation == "tabs" then
		local pattern = [[s/\(^\s*\)\@<=\t/]] .. string.rep(" ", ts) .. "/ge"
		pattern = range == 2 and "'<,'>" .. pattern or "%" .. pattern
		vim.cmd("set et|" .. pattern)
		current_deviator = "tabs"
	elseif indentation == "spaces" then
		local pattern = [[s/\(^\s*\)\@<= \{]] .. ts .. "}/\t/ge"
		pattern = range == 2 and "'<,'>" .. pattern or "%" .. pattern
		vim.cmd("silent set noet|" .. pattern)
		current_deviator = "spaces"
	end
end

---@param range 0|2
function M.standartize(range)
	-- Tabs to spaces
	if current_deviator == "tabs" then
		M.convert("tabs", range)
		return
	end

	-- Spaces to tabs
	M.convert("spaces", range)

	-- Spaces can be sticky little bastards, especially if they are inserted in a quantity that does not match the
	-- currently configured tab stop value. After re-tabbing, we need to check for residue.
	for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
		local remaining_spaces = line:match("^ +")
		local ts_store = vim.bo.tabstop
		if remaining_spaces and #remaining_spaces > 0 then
			vim.bo.tabstop = #remaining_spaces
			M.convert("spaces", range)
			vim.bo.tabstop = ts_store
		end
	end
end

local function create_cmds()
	if not config.user_commands then return end

	api.nvim_create_user_command(CLUSTER .. "Toggle", function(opts)
		local enable = vim.g[PLUGIN] == 0 and true or false
		local buf = false
		if opts.args ~= "" then
			enable = opts.args:match("on") and true or opts.args:match("off") and false or enable
			buf = opts.args:match("buf") and true or buf
		end
		M.toggle(enable, buf)
	end, {
		nargs = "?",
		complete = function() return { "on", "off", "buf_on", "buf_off" } end,
	})

	api.nvim_create_user_command(
		CLUSTER .. "Standardize",
		function(opts) M.standartize(opts.range) end,
		{ range = "%" }
	)

	api.nvim_create_user_command(CLUSTER .. "Convert", function(opts)
		local indentation = opts.args == "tabs_to_spaces" and "tabs" or opts.args == "spaces_to_tabs" and "spaces"
		if not indentation then return end
		M.convert(indentation, opts.range)
	end, {
		nargs = 1,
		complete = function() return { "tabs_to_spaces", "spaces_to_tabs" } end,
		range = "%",
	})
end

-- Setup ======================================================================

---@param user_config? Config
function M.setup(user_config)
	config = vim.tbl_deep_extend("keep", user_config or {}, config)
	vim.g[PLUGIN] = 1
	set_ignored()
	create_aus()
	create_cmds()
end

return M

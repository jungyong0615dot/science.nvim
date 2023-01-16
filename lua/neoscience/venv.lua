local M = {}

local Scan = require("plenary.scandir")

local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local conf = require("telescope.config").values

M.get_venvs = function()
	miniconda_scan =
		Scan.scan_dir("/usr/local/Caskroom/miniconda/base/envs", { hidden = false, depth = 1, only_dirs = true })
	home_venvs_scan = Scan.scan_dir(vim.fn.expand("~") .. "/venvs", { hidden = false, depth = 1, only_dirs = true })
	venvs = {}
	for _, env_scan in ipairs({ miniconda_scan, home_venvs_scan }) do
		for _, dir in ipairs(env_scan) do
			table.insert(venvs, dir .. "/bin")
		end
	end
  return venvs
end

M.open_ipython_with_pick = function(opts)
  require "plugins.configs.telescope"
	pickers
		.new(opts, {
			prompt_title = "Select a session",
			results_title = "Sessions",
			finder = finders.new_table({
				results = M.get_venvs(),
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry,
						ordinal = entry,
					}
				end,
			}),
			sorter = conf.file_sorter({}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = actions_state.get_selected_entry()
					actions.close(prompt_bufnr)
					print("Enjoy venv! You picked:", selection.display)
          require('custom.plugins.lspconfig').set_python_lsp(selection.display)
          require('neovim-ds.lua.kernel').open_ipykernel(selection.display .. '/python3')
				end)
				return true
			end,
		})
		:find()
end

M.open_ipython_with_pick_kitty = function(opts, kitty_title)
  require "plugins.configs.telescope"
	pickers
		.new(opts, {
			prompt_title = "Select a session",
			results_title = "Sessions",
			finder = finders.new_table({
				results = M.get_venvs(),
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry,
						ordinal = entry,
					}
				end,
			}),
			sorter = conf.file_sorter({}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = actions_state.get_selected_entry()
					actions.close(prompt_bufnr)
					print("Enjoy venv! You picked:", selection.display)
          require('custom.plugins.lspconfig').set_python_lsp(selection.display)
          require('neovim-ds.lua.kitty').open_ipykernel({} ,kitty_title, selection.display .. '/python3')
				end)
				return true
			end,
		})
		:find()
end


return M

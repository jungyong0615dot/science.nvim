local M = {}

local Path = require('plenary.path')
local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local conf = require("telescope.config").values

local kernel = require('neovim-ds.lua.kernel')

M.open_kitty_layout = function(opts)
  require "plugins.configs.telescope"
	pickers
		.new(opts, {
			prompt_title = "Select a layout",
			results_title = "Sessions",
			finder = finders.new_table({
				results = {'window', 'tab', 'os-window'},
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
          M.open_kitty(selection.display, 'kk')
				end)
				return true
			end,
		})
		:find()
end

M.open_kitty = function(type, kitty_title)
  -- type: layout type
  result =  os.execute("kitty @ launch --type " .. type .. " --allow-remote-control --title '" .. kitty_title .. "'")
  vim.g.target_kitty_title = kitty_title
  return result
end

M.focus_kitty = function(kitty_title)
  return os.execute("kitty @ focus-window --match title:" .. kitty_title)
end

M.focus_ipython = function()
  return os.execute("kitty @ focus-window --match title:" .. vim.g.kitty_title)
end

M.open_ipykernel = function(opts, kitty_title, python_executable)
  if kitty_title == nil then
    kitty_title = require('neovim-ds.lua.utils').randomString(5)
  end

  python_executable = python_executable or os.getenv("NVIM_NEODS_PYTHON")
  ipython3 = Path:new(python_executable):parent() / 'ipython3'


  require "plugins.configs.telescope"
	pickers
		.new(opts, {
			prompt_title = "Select a layout",
			results_title = "Sessions",
			finder = finders.new_table({
				results = {'window', 'tab', 'os-window'},
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
          M.open_kitty(selection.display, kitty_title)
          vim.g.neods_output_buf = os.getenv("NVIM_NEODS_OUTPUT") .. "tmp_" .. require('neovim-ds.lua.utils').randomString(5) .. ".md"
          vim.g.neods_target_channel = vim.v.servername
          vim.g.kitty_title = kitty_title
          vim.cmd('sleep 100m')
          getcwd = vim.fn.getcwd()
          M.send_text(kitty_title, 'cd ' .. getcwd .. '\r')
          M.send_text(kitty_title, ipython3 .. ' -i --no-autoindent --profile=neods\r')
				end)
				return true
			end,
		})
		:find()

end

M.send_text = function(kitty_title, cmd)
  -- Note: cmd should contain \r
  kitty_title = kitty_title or vim.g.kitty_title
  return os.execute("kitty @ send-text --match title:" .. kitty_title .. " " .. cmd)
end

M.send_code = function(kitty_title, code)
  kitty_title = kitty_title or vim.g.kitty_title

  term_cmd = "%%neods_kitty output --stream-buffer " .. vim.g.neods_output_buf .. " --vpath " .. vim.g.neods_target_channel .. "\r" .. code .. "\r\r\r"
  M.send_text(kitty_title, term_cmd)
end

M.send_current_section = function()
  code = kernel.get_section()
  vim.fn.writefile({code}, vim.g.neods_output_buf .. "_code")
  M.send_code(vim.g.kitty_title, '_=1')
end

return M

local M = {}

local Path = require('plenary.path')
local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local conf = require("telescope.config").values

local kernel = require('neoscience.kernel')

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
  vim.t.target_kitty_title = kitty_title
  return result
end

M.focus_kitty = function(kitty_title)
  return os.execute("kitty @ focus-window --match title:" .. kitty_title)
end

M.focus_ipython = function()
  return os.execute("kitty @ focus-window --match title:" .. vim.t.kitty_title)
end

M.open_ipykernel = function(opts, kitty_title, python_executable)
  if kitty_title == nil then
    kitty_title = vim.t.main_notebook .. "_" .. require('neoscience.utils').randomString(5)
  end

  python_executable = python_executable or os.getenv("NVIM_SCIENCE_PYTHON")
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
          vim.g.neods_output_buf = os.getenv("NVIM_SCIENCE_OUTPUT") .. "tmp_" .. kitty_title .. ".md"

          vim.g.neods_target_channel = vim.v.servername
          vim.t.kitty_title = kitty_title

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
  kitty_title = kitty_title or vim.t.kitty_title
  return os.execute("kitty @ send-text --match title:" .. kitty_title .. " " .. cmd)
end

M.send_code = function(kitty_title, code)
  kitty_title = kitty_title or vim.t.kitty_title

  term_cmd = "%%neods_kitty output --stream-buffer " .. vim.g.neods_output_buf .. " --vpath " .. vim.g.neods_target_channel .. "\r" .. code .. "\r\r\r"
  M.send_text(kitty_title, term_cmd)
end

M.send_current_section = function()
  code = kernel.get_section()
  vim.fn.writefile({code}, vim.g.neods_output_buf .. "_code")
  M.send_code(vim.t.kitty_title, '_=1')
end


M.reconnect = function()
  local kitty_list = vim.fn.system("kitty @ ls")
  local kitty_windows = vim.json.decode(kitty_list)[1].tabs[1].windows
  local ipython_windows = {}

  for _, window in ipairs(kitty_windows) do
    if window["foreground_processes"] ~= nil then
      cmdlines = window["foreground_processes"][1]["cmdline"]
      for _, cmdline in ipairs(cmdlines) do
        if string.find(cmdline, "ipython") then
          table.insert(ipython_windows, {title = window["title"], id = window["id"], cwd = window["cwd"]})
        end
      end
    end
  end

	pickers
		.new({}, {
			prompt_title = "Select window",
			results_title = "windows",
			finder = finders.new_table({
				results = ipython_windows,
				entry_maker = function(entry)
					return {
						value = entry["title"],
						display = entry["title"] .. " - " .. entry["cwd"],
						ordinal = entry["cwd"],
					}
				end,
			}),
			sorter = conf.file_sorter({}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = actions_state.get_selected_entry()
					actions.close(prompt_bufnr)
					print("Enjoy venv! You picked:", selection.value)
          vim.g.neods_output_buf = os.getenv("NVIM_SCIENCE_OUTPUT") .. "tmp_" .. selection.value .. ".md"

          vim.g.neods_target_channel = vim.v.servername
          vim.t.kitty_title = selection.value
				end)
				return true
			end,
		})
		:find()
end

return M

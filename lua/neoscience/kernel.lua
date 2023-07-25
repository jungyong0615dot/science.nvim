local M = {}

local Path = require("plenary.path")

local function script_path()
	-- show current path of plugin. e.g.
	local str = debug.getinfo(2, "S").source:sub(2)
	return str:match("(.*/)")
end

M.save_code_to_file = function(code, file)
	-- TODO: replace to json
	vim.fn.writefile({ code }, file)
end

M.get_section = function()
	-- get the section code where the cursor positioned
	local pos1 = vim.fn.search("# %%", "nbW") + 1
	local pos2 = vim.fn.search("# %%", "nW")
	if (pos2 == nil) or (pos2 == 0) then
		pos2 = vim.fn.line("$")
	else
		pos2 = pos2 - 1
	end
	local code = vim.fn.join(vim.fn.getline(pos1, pos2), "\n")

	return code
end

M.move_cursor = function(direction)
	-- get the section code where the cursor positioned
	local pos1 = vim.fn.search("# %%", "nbW") - 1
	local pos2 = vim.fn.search("# %%", "nW") + 2
	if (pos2 == nil) or (pos2 == 0) then
		pos2 = vim.fn.line("$")
	else
		pos2 = pos2 - 1
	end
	if direction == "up" then
		vim.api.nvim_win_set_cursor(0, { pos1, 1 })
	elseif direction == "v_up" then
		vim.api.nvim_win_set_cursor(0, { pos1 + 3, 1 })
	elseif direction == "down" then
		vim.api.nvim_win_set_cursor(0, { pos2, 1 })
	elseif direction == "v_down" then
		vim.api.nvim_win_set_cursor(0, { pos2 - 2, 1 })
	end

	return code
end

M.format_current_section = function()
	local pos1 = vim.fn.search("# %%", "nbW") + 1
	local pos2 = vim.fn.search("# %%", "nW") - 1
	if (pos2 == nil) or (pos2 == 0) then
		pos2 = vim.fn.line("$")
	end
	require("neoscience.formatter").format_dat_sql(nil, pos1, pos2)

	local pos1 = vim.fn.search("# %%", "nbW") + 1
	local pos2 = vim.fn.search("# %%", "nW") - 1
	-- vim.fn.append(pos2 - 1, '\r')
	vim.api.nvim_buf_set_lines(0, pos2, pos2, false, { "" })
	vim.api.nvim_buf_set_lines(0, pos1, pos1, false, { "" })
end

M.send_current_section = function(terminal_job_id)
	local code = M.get_section()
	M.send_code(terminal_job_id, code)
	--   M.save_code_to_file(code, vim.g.neods_output_buf .. "_code") -- TODO: replace to json
	--   M.ipython_send_code(terminal_job_id, [[
	-- print("send")
	--   ]])
end

M.send_code = function(terminal_job_id, code)
	if terminal_job_id == nil then
		local terminal_job_ids, _ = require("neoscience.terminal").get_terminals()
		terminal_job_id = terminal_job_ids[1]
	end
	M.save_code_to_file(code, vim.g.neods_output_buf .. "_code") -- TODO: replace to json
	M.ipython_send_code(
		terminal_job_id,
		[[
print("send")
  ]]
	)
end

M.async_send_current_section = function(terminal_job_id, target_processor, block)
	-- send current section to ipython kernel
	if terminal_job_id == nil then
		local terminal_job_ids, _ = require("neoscience.terminal").get_terminals()
		terminal_job_id = terminal_job_ids[1]
	end

	local code = M.get_section()
	M.save_code_to_file(code, vim.g.neods_output_buf .. "_code") -- TODO: replace to json
	M.async_ipython_send_code(
		terminal_job_id,
		[[
print("send")
  ]],
		target_processor,
		block
	)
end

M.ipython_send_code = function(terminal_job_id, code)
	-- Send codes to specified terminal
	term_cmd = "%%neods output --stream-buffer "
		.. vim.g.neods_output_buf
		.. " --vpath "
		.. vim.g.neods_target_channel
		.. "\n"
		.. code
		.. "\r\r"
	require("neoscience.terminal").send_command(terminal_job_id, term_cmd)
end

M.async_ipython_send_code = function(terminal_job_id, code, target_processor, block)
	-- Send codes to specified terminal
	local term_cmd = nil
	if block == nil then
		term_cmd = "%%px --targets "
			.. target_processor
			.. " \n"
			.. "%%async_neods --stream-buffer "
			.. vim.g.neods_output_buf
			.. " --vpath "
			.. vim.g.neods_target_channel
			.. "\n"
			.. code
			.. "\r\r"
	else
		term_cmd = "%%px --targets "
			.. target_processor
			.. " --noblock"
			.. "\n"
			.. "%%neods output --stream-buffer "
			.. vim.g.neods_output_buf
			.. " --vpath "
			.. vim.g.neods_target_channel
			.. "\n"
			.. code
			.. "\r\r"
	end
	require("neoscience.terminal").send_command(terminal_job_id, term_cmd)
end

M.open_ipykernel = function(python_executable)
	python_executable = python_executable or os.getenv("NVIM_SCIENCE_PYTHON")

	-- open output buffer
	-- TODO: default path
	vim.g.neods_output_buf = os.getenv("NVIM_SCIENCE_OUTPUT")
		.. "tmp_"
		.. require("neoscience.utils").randomString(5)
		.. ".md"
	vim.cmd("e " .. vim.g.neods_output_buf)

	-- Open ipython kernel with new nvim terminal, and temporary buffer
	vim.cmd("terminal")
	vim.cmd("sleep 100m")

	local terminal_job_ids, _ = require("neoscience.terminal").get_terminals()

	local ipython3 = Path:new(python_executable):parent() / "ipython3"

	-- get current instance's channel
	vim.g.neods_target_channel = vim.v.servername

	-- Startup commands for ipython
	local lua_path = script_path()
	local startup_cmds = {}
	table.insert(startup_cmds, "os.environ['NEODS_ASYNC_BUF'] = '" .. vim.g.neods_output_buf .. "'")

	table.insert(startup_cmds, "os.environ['NEODS_ASYNC_VPATH'] = '" .. vim.g.neods_target_channel .. "'")
	-- table.insert(startup_cmds, "from pathlib import Path")
	-- table.insert(startup_cmds, "import sys")
	-- table.insert(startup_cmds, "import matplotlib")
	-- table.insert(startup_cmds, "matplotlib.rcParams['figure.figsize'] = (12, 12)")
	-- table.insert(startup_cmds, "matplotlib.rcParams['axes.labelsize'] = 20")
	-- table.insert(startup_cmds, "matplotlib.rcParams['axes.titlesize'] = 20")
	-- table.insert(startup_cmds, "matplotlib.rcParams['xtick.labelsize'] = 20")
	-- table.insert(startup_cmds, "matplotlib.rcParams['ytick.labelsize'] = 20")
	-- table.insert(startup_cmds, "sys.path.append(str(Path(\\\"" .. lua_path .."\\\").parent / \\\"python\\\"))")
	-- table.insert(startup_cmds, "from stream import DsMagic, kshow")
	-- table.insert(startup_cmds, "from IPython import get_ipython")
	-- table.insert(startup_cmds, "get_ipython().register_magics(DsMagic)")
	-- table.insert(startup_cmds, "import ipyparallel as ipp")
	-- table.insert(startup_cmds, "rc = ipp.Cluster(n=4).start_and_connect_sync()")

	local startup_cmd = ""
	for _, cmd in ipairs(startup_cmds) do
		startup_cmd = startup_cmd .. cmd .. ";"
	end

	-- open ipython
	require("neoscience.terminal").send_command(
		terminal_job_ids[1],
		ipython3 .. ' -i --no-autoindent --profile=neods -c "' .. startup_cmd .. '"'
	)
	vim.cmd("sleep 1")
	vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
		pattern = { "*.md", "*.py" },
		callback = function()
			if vim.api.nvim_get_mode().mode ~= "c" and vim.fn.pumvisible() == 0 then
				vim.api.nvim_command("checktime")
				-- vim.api.nvim_command("e")
			end
		end,
	})
end

M.create_marker = function(type, is_cell_end)
	-- type: python, markdown
	-- if the end of the doc, add one more marker -> It's because of the treesitter highlight behaviour.
	local marker = nil
	if type == "python" then
		marker = { "# %% NOTE:", "#  ", "", "" }
	elseif type == "markdown" then
		marker = { "", "# %% NOTE: [markdown]", '_ = """', "<!--markdown-->", "", '"""', "", "" }
	else
		marker = { "##", "", "" }
	end
	if is_cell_end then
		table.insert(marker, "# %% NOTE:")
	end
	return marker
end

M.create_cell = function(type, cmd)
	-- type: python, markdown
	-- cmd: below, above
	local newcursor = nil
	local target_line = nil
	local next_cell = nil
	local is_cell_end = nil
	local prev_cell = nil

	if cmd == "below" then
		target_line = vim.fn.line(".")

		next_cell = vim.fn.search("# %%", "nW")
		if (next_cell == nil) or (next_cell == 0) then
			target_line = vim.fn.line("$")
			is_cell_end = true
		else
			target_line = next_cell - 1
			is_cell_end = false
		end

		newcursor = target_line + 2
	elseif cmd == "above" then
		prev_cell = vim.fn.search("# %%", "nbW")

		if (prev_cell == nil) or (prev_cell < 2) then
			target_line = 1
		else
			target_line = prev_cell - 1
		end
	end

	if type == "python" then
		newcursor = target_line + 2
	elseif type == "markdown" then
		newcursor = target_line + 5
	end

	local marker = M.create_marker(type, is_cell_end)
	vim.fn.append(target_line, marker)

	if is_cell_end then
		newcursor = newcursor + 1
	end
	vim.api.nvim_win_set_cursor(0, { newcursor, 3 })
	vim.api.nvim_command("startinsert")
end

M.convert_to_ipynb = function(input)
	if input == "" then
		input = vim.fn.expand("%:p")
	end
	local output = string.sub(input, 0, -4) .. ".ipynb"
	local lua_path = Path:new(script_path()):parent():parent():absolute()
	local converter = Path:new(lua_path, "python", "convert.py"):absolute()
	vim.fn.system(
		os.getenv("NVIM_SCIENCE_PYTHON") .. " " .. converter .. " --input " .. input .. " --output " .. output
	)
	print("converted to " .. output)
end


M.convert_to_py = function(input_file, output_file)
  local input = vim.fn.json_decode(vim.fn.readfile(input_file))
  
  local lines = {}
  for _, cell in ipairs(input.cells) do
    if cell.cell_type == "code" then
      table.insert(lines, "# %% NOTE:")
      local source = cell.source
      for _, line in ipairs(source) do
        -- replace \n into blanK
        line = string.gsub(line, "\n", "")
        table.insert(lines, line)
      end
      table.insert(lines, "")
    elseif cell.cell_type == "markdown" then
      local source = cell.source
      table.insert(lines, "# %% NOTE: [markdown]")
      table.insert(lines, '_ = """')
      table.insert(lines, "<!--markdown-->")
      for _, line in ipairs(source) do
        line = string.gsub(line, "\n", "")
        table.insert(lines, line)
      end
      table.insert(lines, '"""')
      table.insert(lines, "")
    end
  end
  vim.fn.writefile(lines, output_file)
  -- vim.pretty_print(vim.fn.join(lines, "\n"))
end

return M

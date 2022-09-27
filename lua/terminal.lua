local M = {}

local charset = "qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890"
math.randomseed(os.clock())

local function randomString(length)
  -- generate random string with specified length. it's used for tmp buffer, cell id generation.
  local ret = {}
  local r
  for _ = 1, length do
    r = math.random(1, #charset)
    table.insert(ret, charset:sub(r, r))
  end
  return table.concat(ret)
end

local function aggregate_startup_commands(cmds)
  -- aggregate ipython startup commands
  startup = ''
  for _, cmd in ipairs(cmds) do
    startup = startup .. cmd .. ';'
  end
  return startup
end

local function script_path()
  -- show current path of plugin. e.g. $HOME/.config/nvim/lua/neovim-ds/lua/
  local str = debug.getinfo(2, "S").source:sub(2)
  return str:match("(.*/)")
end

M.get_terminals = function ()
  -- Get list of nvim terminals from current nvim instance. return job_ids and bufnrs
  terminal_job_ids = {}
  terminal_bufnrs = {}
  for _, v in ipairs(vim.fn.getbufinfo({bufloaded =  1})) do
    if v.variables.terminal_job_id then
      table.insert(terminal_job_ids, v.variables.terminal_job_id)
      table.insert(terminal_bufnrs, v.bufnr)
    end
  end
  return terminal_job_ids, terminal_bufnrs
end

M.send_command = function(terminal_job_id, term_cmd)
  -- Send command to specified terminal
  term_cmd = term_cmd .. "\r"
  -- let text = substitute(a:text, '\n$\|\r$', ' ', '')
  vim.api.nvim_chan_send(terminal_job_id, term_cmd)
end

M.open_ipykernel = function()

  -- Open ipython kernel with new nvim terminal, and temporary buffer
  vim.cmd("terminal")
  vim.cmd('sleep 1')
  local terminal_job_ids, _ = M.get_terminals()

  -- conda activate
  -- TODO: deal with multiple terminals
  -- TODO: python env as variable
  M.send_command(terminal_job_ids[1], 'conda activate nds')
  vim.cmd('sleep 1')

  -- get current instance's channel
  vim.g.neods_target_channel = vim.v.servername

  -- Startup commands for ipython
  lua_path = script_path()
  startup_cmds = {}
  table.insert(startup_cmds, "from pathlib import Path")
  table.insert(startup_cmds, "import sys")
  table.insert(startup_cmds, "sys.path.append(str(Path(\\\"" .. lua_path .."\\\").parent / \\\"python\\\"))")
  table.insert(startup_cmds, "from stream import DsMagic")
  table.insert(startup_cmds, "from IPython import get_ipython")
  table.insert(startup_cmds, "get_ipython().register_magics(DsMagic)")
  startup_cmd = aggregate_startup_commands(startup_cmds)

  -- open ipython
  M.send_command(terminal_job_ids[1], 'ipython -i --no-autoindent -c "' .. startup_cmd .. '"')
  vim.cmd('sleep 1')

  -- open output buffer
  -- TODO: default path
  vim.g.neods_output_buf = "/Users/jungyonglee/Jungyong/tmp/nds/ouptut/tmp_" .. randomString(5) .. ".md"
  vim.cmd("e " .. vim.g.neods_output_buf)
end

M.ipython_send_code = function(terminal_job_id, code)
  -- Send codes to specified terminal
  term_cmd = "%%neods output --stream-buffer " .. vim.g.neods_output_buf .. " --vpath " .. vim.g.neods_target_channel .. "\n" .. code .. "\r\r"
  M.send_command(terminal_job_id, term_cmd)
end

M.get_section = function()
  local pos1 = vim.fn.search('# %%', 'nbW') + 1
  local pos2 = vim.fn.search('# %%', 'nW')
  if (pos2 == nil)  or (pos2 == 0) then
    pos2 = vim.fn.line('$')
  else
    pos2 = pos2 - 1
  end
  code = vim.fn.join(vim.fn.getline(pos1, pos2), '\n')

  return code
end

M.save_code_to_file = function(code, file)
  -- TODO: replace to json
  vim.fn.writefile({code}, file)
end

M.send_current_section = function(terminal_job_id)
  if terminal_job_id == nil then
    local terminal_job_ids, _ = M.get_terminals()
    terminal_job_id = terminal_job_ids[1]
  end
  code = M.get_section()
  M.save_code_to_file(code, vim.g.neods_output_buf .. "_code") -- TODO: replace to json
  M.ipython_send_code(terminal_job_id, [[
print("")
  ]])
end


M.tmp1 = function()
  print("HI")
end


return M

local M = {}

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

M.tmp1 = function()
  print("HI")
end


return M

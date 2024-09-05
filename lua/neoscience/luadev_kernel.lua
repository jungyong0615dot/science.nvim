local M = {}
local luadev = require('luadev')

local get_section = function()
  -- get the section code where the cursor positioned
  local pos1 = vim.fn.search('--%%', 'nbW') + 1
  local pos2 = vim.fn.search('--%%', 'nW')
  if (pos2 == nil)  or (pos2 == 0) then
    pos2 = vim.fn.line('$')
  else
    pos2 = pos2 - 1
  end
  local code = vim.fn.join(vim.fn.getline(pos1, pos2), '\n')

  return code
end

M.send_current_section = function()
  local lines = get_section()
  luadev.exec(lines)
end

M.create_marker = function(_, is_cell_end)
  -- type: python, markdown
  -- if the end of the doc, add one more marker -> It's because of the treesitter highlight behaviour.
  local marker = nil

  marker = {'--%% NOTE: ', '-- ', '', ''}
  if is_cell_end then
    table.insert(marker, '--%% NOTE: ')
  end
  return marker
end

M.create_cell = function(cmd)
  -- cmd: below, above
  local target_line = nil
  local next_cell = nil
  local is_cell_end = nil
  local newcursor = nil
  local prev_cell = nil

  if cmd == "below" then
    target_line = vim.fn.line('.')

    next_cell = vim.fn.search('--%%', 'nW')
    if (next_cell == nil)  or (next_cell == 0) then
      target_line = vim.fn.line('$') - 1
      is_cell_end = true
    else
      target_line = next_cell - 1
      is_cell_end = false
    end

    newcursor = target_line + 2
  elseif cmd == "above" then
    prev_cell = vim.fn.search('--%%', 'nbW')

    if (prev_cell == nil)  or (prev_cell < 2) then
      target_line = 1
    else
      target_line = prev_cell - 1
    end
  end

  newcursor = target_line + 1

  local marker = M.create_marker(type, is_cell_end)
  vim.fn.append(target_line, marker)

  if is_cell_end then
    newcursor = newcursor + 1
  end
  vim.api.nvim_win_set_cursor(0, {newcursor, 10})
  vim.api.nvim_command('startinsert')
end

return M

local M = {}
local embedded_sql = vim.treesitter.parse_query(
"python",
  [[
(
(string) @sql
(#match? @sql "--.*sql")
(#offset! @sql 0 3 0 -3)
)
  ]]
)

local formatter = require('formatter.format')

M.get_root = function(bufnr)
  local parser = vim.treesitter.get_parser(bufnr, "python", {})
  local tree = parser:parse()[1]
  return tree:root()
end

M.open_floating_cell = function(filetype)
  if filetype == 'python' or filetype == "lua" or filetype == "markdown" then

    local width = vim.api.nvim_get_option("columns")
    local height = vim.api.nvim_get_option("lines")
    local win_height = math.ceil(height * 0.7 - 4)
    local win_width = math.ceil(width * 0.7)
    local row = math.ceil((height - win_height) / 2 - 1)
    local col = math.ceil((width - win_width) / 2)
    local buf = vim.api.nvim_create_buf(true, true)

    vim.api.nvim_buf_set_option(buf, "filetype", filetype)
    vim.b[buf].parent_buf = vim.api.nvim_get_current_buf()
    local _ = vim.api.nvim_open_win(buf, true, {style = "minimal", relative = "editor",row=row, col=col, width=win_width, height=win_height, border = "rounded"})
    vim.w.is_floating_scratch = true
    return
  end

  local cell_sql = nil
  if vim.bo.filetype == "python" then
    local pos1 = vim.fn.search('# %%', 'nbW') + 1
    local pos2 = vim.fn.search('# %%', 'nW') - 1
    if (pos2 == nil)  or (pos2 == 0) then
      pos2 = vim.fn.line('$')
    end

    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local root = M.get_root(bufnr)
    local ranges = {}
    for id, node in embedded_sql:iter_captures(root, bufnr, 0, -1) do
      local name = embedded_sql.captures[id]
      if name == "sql" then
        local range = {node:range()}
        table.insert(ranges, 1, {range[1]+2, range[3]})
      end
    end

    for _, range in ipairs(ranges) do
      if range[1] >= pos1 and range[2] <= pos2 then
        cell_sql = vim.api.nvim_buf_get_lines(bufnr, range[1], range[2], true)
      end
    end
  else
    cell_sql = vim.api.nvim_buf_get_lines(0, 0, -1, true)
  end

  if cell_sql ~= nil then
    local width = vim.api.nvim_get_option("columns")
    local height = vim.api.nvim_get_option("lines")
    local win_height = math.ceil(height * 0.7 - 4)
    local win_width = math.ceil(width * 0.7)
    local row = math.ceil((height - win_height) / 2 - 1)
    local col = math.ceil((width - win_width) / 2)
    local buf = vim.api.nvim_create_buf(true, true)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, cell_sql)
    vim.api.nvim_buf_set_option(buf, "filetype", filetype)
    vim.b[buf].parent_buf = vim.api.nvim_get_current_buf()
    vim.b[buf].is_tmp_sql = true
    -- local win = vim.api.nvim_open_win(buf, true, {style = "minimal", relative = "editor",row=row, col=col, width=win_width, height=win_height, border = "rounded"})
    local win = vim.api.nvim_open_win(buf, true, {relative = "editor",row=row, col=col, width=win_width, height=win_height, border = "rounded"})
    vim.w.is_floating_scratch = true
  end
end

M.format_dat_sql = function(bufnr, pos1, pos2)
  pos1 = pos1 or 1
  pos2 = pos2 or vim.api.nvim_buf_line_count(0)
  formatter.start_task({{config = {exe ="yapf", stdin = true }, name = "yapf"}}, pos1, pos2, nil)
  vim.cmd('sleep 400m')
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local root = M.get_root(bufnr)
  local ranges = {}
  for id, node in embedded_sql:iter_captures(root, bufnr, 0, -1) do
    local name = embedded_sql.captures[id]
    if name == "sql" then
      local range = {node:range()}
      table.insert(ranges, 1, {range[1]+2, range[3]})
    end
  end

  for _, range in ipairs(ranges) do
    if range[1] >= pos1 and range[2] <= pos2 then
      -- formatter.start_task({{config = {exe ="pg_format", stdin = true }, name = "pgformat"}}, range[1], range[2], nil)
      print(range[1])
      print(range[2])

      file_o = io.open("/tmp/sqlfile", "w+")
      for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, range[1], range[2], true)) do
        file_o:write(line .. '\n')
      end
      file_o:close()

      formatter.start_task({{
        config = {
          exe = "dbt-formatter",
          args = {
            "--upper",
            "--file",
            "/tmp/sqlfile",
          },
          stdin = true,
        },
      }}, range[1], range[2], nil)
      vim.cmd('sleep 400m')
    end
  end
end

return M

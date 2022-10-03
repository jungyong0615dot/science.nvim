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

M.format_dat_sql = function(bufnr, pos1, pos2)
  pos1 = pos1 or 1
  pos2 = pos2 or vim.api.nvim_buf_line_count(0)
  formatter.start_task({{config = {exe ="yapf", stdin = true }, name = "yapf"}}, pos1, pos2, nil)
  vim.cmd('sleep 100m')
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
      formatter.start_task({{config = {exe ="pg_format", stdin = true }, name = "pgformat"}}, range[1], range[2], nil)
      vim.cmd('sleep 100m')
    end
  end
end

return M

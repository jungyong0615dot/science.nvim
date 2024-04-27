local M = {}

local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values

local ts_utils = require("telescope.utils")
local defaulter = ts_utils.make_default_callable

local cell_previewer = defaulter(function(opts)
	return previewers.new_buffer_previewer({
		title = "cell",
		get_buffer_by_name = function(_, entry)
			return entry.text
		end,
		define_preview = function(self, entry)
			local bufnr = self.state.bufnr
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(entry.text, "\n"))
			vim.api.nvim_buf_set_option(bufnr, "filetype", entry.type)
		end,
	})
end)

local is_md_cell = function(lines)
  for _, line in ipairs(lines) do
    if string.match(line, '--markdown--') then
      return true
    end
  end
  return false
end

local get_markdown_lines = function(lines)
  md_lines = {}
  for _, line in ipairs(lines) do
    if string.match(line, '--markdown--') == nil and line ~= '' and string.match(line, '"""') == nil then
      table.insert(md_lines, line)
    end
  end
  return md_lines
end


M.show_cells = function(open)
  if vim.bo.filetype ~= 'python' and vim.bo.filetype ~= 'lua' then
    return nil
  end


	local current_buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	-- current_buffer = vim.fn.join(current_buffer, "\n")
	local current_cursor = vim.api.nvim_win_get_cursor(0)[1]
	local default_selection_index = 1

	local num_line = 1
  local sections = {}
  local section = {type='python', lines={}, title='', cell='', line_start=0, line_end=0}
  for idx, line in ipairs(current_buffer) do
    if string.match(line, 'NOTE:') or string.match(line, '%%%%') or idx == #(current_buffer) then
      if vim.bo.filetype == 'python' then
        if is_md_cell(section.lines) and vim.bo.filetype == 'python' then
          section.type = 'markdown'
        else
          section.type = 'python'
        end
      elseif vim.bo.filetype == 'lua' then
        section.type = 'lua'
      end

      if section.type == 'python' or section.type == 'lua' then

        if #(section.lines) > 0 and (string.sub(section.lines[1], 1, 1) == "#" or string.sub(section.lines[1], 1, 1) == "-") then
          local title_str = section.lines[1]:gsub(" code-summary:", ""):sub(3)
          section.title = ' v ' .. title_str
        else
          section.title = ''
        end
        section.cell = vim.fn.join(table.move(section.lines, 2, #(section.lines), 1, {}), "\n")
      elseif section.type == 'markdown' then
        md_lines = get_markdown_lines(section.lines)
        section.cell = vim.fn.join(table.move(md_lines, 1, #(md_lines), 1, {}), "\n")
        section.title = md_lines[1]
      end

      section.line_start = num_line
      section.line_end = num_line + #(section.lines)

      if current_cursor >= section.line_start and current_cursor <= section.line_end then
        default_selection_index = #(sections) + 1
      end
      num_line = num_line + #(section.lines) + 1

      if #(section.lines) > 0 then
        table.insert(sections, section)
      end

      section = {type=section.type, lines={}, title='', cell='', line_start=0, line_end=0}
    else
      table.insert(section['lines'], line)
    end
  end



  if open == true then
    pickers
      .new({}, {
        prompt_title = "Cells",
        results_title = "cells",
        finder = finders.new_table({
          results = sections,
          entry_maker = function(entry)
            return {
              value = entry.title,
              display = entry.title,
              text = entry.cell,
              ordinal = entry.title,
              type = entry.type,
              line_start = entry.line_start,
            }
          end,
        }),
        previewer = cell_previewer.new({}),
        sorter = conf.file_sorter({}),
        default_selection_index = default_selection_index,
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            local selection = actions_state.get_selected_entry()
            actions.close(prompt_bufnr)
            vim.api.nvim_win_set_cursor(0, { selection.line_start, 0 })
          end)
          return true
        end,
      })
      :find()
  else
    return sections
  end
end

return M

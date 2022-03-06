-- TODO
-- fix(movements): first/last siblings (K/J)
-- fix(movements): next/prev siblings (>/<)
-- fix(algorithm): apply filter on grouped nodes
-- fix(rendering): padding with indent markers does not detect last node properly
-- improve: matching algorithm
-- improve: folder expansion -> might involve performance issues that could be resolved with max depth search
-- improve: user configuration
-- improve: make prompt prettier
-- finish: documentation
local a = vim.api

local view = require "nvim-tree.view"

local M = {
  filter = nil,
  prefix = "Filtering on: ",
  depth = 3,
}

local function redraw()
  require("nvim-tree.renderer").draw()
end

local function reset_filter(node_)
  local function iterate(n)
    n.hidden = false
    if n.nodes then
      for _, node in pairs(n.nodes) do
        iterate(node)
      end
    end
  end
  iterate(node_ or TreeExplorer)
end

local overlay_bufnr = nil
local overlay_winnr = nil

function M.remove_overlay()
  vim.cmd "augroup NvimTreeRecordFilter"
  vim.cmd "au!"
  vim.cmd "augroup END"

  a.nvim_win_close(overlay_winnr, { force = true })
  overlay_bufnr = nil
  overlay_winnr = nil

  if M.filter == "" then
    M.filter = nil
    reset_filter()
    redraw()
  end
end

local function matches(node)
  local path = node.cwd or node.link_to or node.absolute_path
  local name = vim.fn.fnamemodify(path, ":t")
  return vim.fn.match(name, M.filter) ~= -1
end

function M.apply_filter(node_)
  if not M.filter or M.filter == "" then
    reset_filter(node_)
    return
  end

  local function iterate(node)
    local filtered_nodes = 0
    if node.nodes then
      for _, n in pairs(node.nodes) do
        if not iterate(n) then
          filtered_nodes = filtered_nodes + 1
        end
      end
    end

    local has_nodes = #(node.nodes or {}) > filtered_nodes
    if has_nodes or matches(node) then
      node.hidden = false
      return true
    end

    node.hidden = true
    return false
  end

  iterate(node_ or TreeExplorer)
end

local function record_char()
  vim.schedule(function()
    M.filter = a.nvim_buf_get_lines(overlay_bufnr, 0, -1, false)[1]
    M.apply_filter()
    redraw()
  end)
end

local function configure_buffer_overlay()
  overlay_bufnr = a.nvim_create_buf(false, true)

  a.nvim_buf_attach(overlay_bufnr, true, {
    on_lines = record_char,
  })
  vim.cmd "augroup NvimTreeRecordFilter"
  vim.cmd "au!"
  vim.cmd "au InsertLeave * lua require'nvim-tree.live-filter'.remove_overlay()"
  vim.cmd "augroup END"

  a.nvim_buf_set_keymap(overlay_bufnr, "i", "<CR>", "<cmd>stopinsert<CR>", {})
end

local function create_overlay()
  configure_buffer_overlay()
  overlay_winnr = a.nvim_open_win(overlay_bufnr, true, {
    col = 1,
    row = 0,
    relative = "cursor",
    width = math.max(20, a.nvim_win_get_width(view.get_winnr()) - #M.prefix - 2),
    height = 1,
    border = "none",
    style = "minimal",
  })
  a.nvim_buf_set_option(overlay_bufnr, "modifiable", true)
  a.nvim_buf_set_lines(overlay_bufnr, 0, -1, false, { M.filter })
  vim.cmd "startinsert"
  a.nvim_win_set_cursor(overlay_winnr, { 1, #M.filter + 1 })
end

function M.start_filtering()
  M.filter = M.filter or ""

  redraw()
  local row = require("nvim-tree.core").get_nodes_starting_line() - 1
  view.set_cursor { row, #M.prefix - 1 }
  -- needs scheduling to let the cursor move before initializing the window
  vim.schedule(create_overlay)
end

return M

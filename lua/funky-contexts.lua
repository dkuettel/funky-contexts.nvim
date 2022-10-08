local M = {}

-- no trailing slashes
local base = "./contexts"

-- a context is a path relative to base as a list of names
-- {"."} is the root context, {".", "some"} is a context with name "some"
local current_context = {}

local function get_paths(context)
    -- return path to folder and path to Session.vim
    local path = base .. "/" .. table.concat(context, "/")
    local file = path .. "/Session.vim"
    return path, file
end

local function save(context)
    local folder, file = get_paths(context)
    -- TODO default mksession and sourcing might do too much (like restore global key mappings)
    vim.fn.system({ "mkdir", "-p", folder })
    vim.cmd("mksession! " .. file)
end

local function load(context)
    local _, file = get_paths(context)
    -- TODO default mksession and sourcing might do too much (like restore global key mappings)
    vim.cmd("source " .. file)
    vim.g.funky_context = table.concat(context, "/")
end

local function delete(context)
    local _, file = get_paths(context)
    -- TODO but we can only delete leaves?
    -- or should it drop all below? or disconnect a tree?
    vim.fn.system({ "rm", "-f", file })
end

function M.new_copy(name)
    -- new context, copy of current context, child of current context
    save(current_context)
    -- TODO check that Session.vim for this context does not exist yet
    table.insert(current_context, name)
    save(current_context)
end

function M.new_empty(name)
    -- new context, empty vim, child of current context
    save(current_context)
    -- TODO check that Session.vim for this context does not exist yet
    table.insert(current_context, name)
    vim.cmd("%bd")
    save(current_context)
end

function M.new_here(name)
    -- new context, empty except current buffer, child of current context
    save(current_context)
    -- TODO check that Session.vim for this context does not exist yet
    table.insert(current_context, name)
    vim.cmd([[
        tabonly
        only
    ]])
    save(current_context)
end

function M.drop()
    -- drop current context, move to parent context
    delete(current_context)
    table.remove(current_context)
    load(current_context)
end

function M.up()
    -- switch to parent context, dont drop current context
    save(current_context)
    table.remove(current_context)
    load(current_context)
end

function M.jump(context)
    -- jump to any context, dont drop current context
    save(current_context)
    current_context = context
    load(current_context)
end

function M.list()
    local found = vim.fn.systemlist("cd " .. base .. "; find . -name Session.vim")
    local contexts = {}
    for i = 1, #found do
        local context = vim.split(found[i], "/")
        table.remove(context)
        table.insert(contexts, context)
    end
    return contexts
end

function M.setup()
    -- this global variable mirrors the current context
    -- (but it doesnt sync, you cannot set it to change the context)
    -- useful to show the context in the status- or tabline
    vim.g.funky_context = "."

    local ucom = vim.api.nvim_create_user_command
    ucom("CNewCopy", function(cmd)
        M.new_copy(cmd["args"])
    end, { nargs = 1 })
    ucom("CNewEmpty", function(cmd)
        M.new_empty(cmd["args"])
    end, { nargs = 1 })
    ucom("CNewHere", function(cmd)
        M.new_here(cmd["args"])
    end, { nargs = 1 })
    ucom("CDrop", M.drop, {})
    ucom("CUp", M.up, {})
    ucom("CJump", function(cmd)
        -- TODO think about interface, contexts are paths, or lists? or both? what's easier
        M.jump(cmd["fargs"])
    end, { nargs = "+" })
    ucom("CList", function()
        vim.pretty_print(M.list())
    end, {})
end

return M

local M = {}

M.lyaml = vim.F.npcall(require, 'lyaml')
-- local lyaml = pcall(require, 'lyaml')
-- local lyaml = require('lyaml')

local Path = require('plenary.path')
local utils = require('toggletasks.utils')

function load_lyaml()
    if M.lyaml == nil then
        M.lyaml = vim.F.npcall(require, 'lyaml')
    end
end

local loaders = {
    json = vim.json.decode,
    yaml = function(s)
        load_lyaml()
        -- Returns the first "YAML document"
        return M.lyaml.load(s)
    end,
}

local dumpers = {
    json = vim.json.encode,
    yaml = function(t)
        load_lyaml()
        -- Expects a list of "YAML documents", so the dumped table must be wrapped in a list
        return M.lyaml.dump { t }
    end,
}

function M.supported_extensions()
    load_lyaml()
    return M.lyaml and { 'json', 'yaml', 'yml' } or { 'json' }
end

-- utils.warn(table.concat(M.supported_extensions()))

local function get_ft(path)
    path = Path:new(path)
    local ext = vim.fn.fnamemodify(path:absolute(), ':p:e'):lower()

    if not vim.tbl_contains(M.supported_extensions(), ext) then
        utils.error(
            'Unsupported config file extension "%s", available: %s',
            utils.short_path(path),
            table.concat(M.supported_extensions(), ', ')
        )
        return
    end

    if ext == 'json' then
        return 'json'
    elseif vim.tbl_contains({ 'yaml', 'yml' }, ext) then
        return 'yaml'
    else
        assert(false, 'Should be unreachable: inconsistent M.supported_extensions')
    end
end

-- Load configuration from a file with supported file format
function M.load_config(file)
    local path = Path:new(file)

    if not path:exists() then
        utils.warn('Config file does not exist: %s', path:absolute())
        return
    end

    load_lyaml()

    -- Dispatch by file extension
    local ft = get_ft(path)
    if not ft then
        return
    elseif ft == 'yaml' and not M.lyaml then
        utils.warn_once('YAML support not available - "lyaml" is not installed - ignoring')
        return
    end

    -- Read file contents
    local content = vim.F.npcall(path.read, path)
    if not content then
        utils.error_once('Could not read task config file: %s', path:absolute())
        return
    end

    -- Parse config
    local load = loaders[ft]
    local conf = vim.F.npcall(load, content)
    if not conf then
        utils.error('Failed to parse tasks config: %s', path:absolute())
        return
    end

    utils.debug('load_config: loaded: %s', utils.short_path(path))
    return conf
end

-- Convert configuration file formats based on given paths' extensions
function M.convert(from_path, to_path)
    from_path = Path:new(from_path)
    to_path = Path:new(to_path)
    local load = loaders[get_ft(from_path)]
    local dump = dumpers[get_ft(to_path)]
    local conf = load(from_path:read())
    to_path:write(dump(conf), 'w')
end

return M

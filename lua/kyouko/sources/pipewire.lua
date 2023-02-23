---@module 'kyouko.sources.pipewire'
---@author andry-dev
---@license GPL-3.0

local global_defaults = require('kyouko.defaults')

--- Generates a Pipewire source.
--- This requires `pw-record` installed.
local M = {}

local source_defaults = {
    channels = 2,
    sample_rate = 48000,
    source = {
        volume = 1.0,
        format = 's16',
        custom_options = ''
    }
}

function M.new(opts)
    opts = vim.tbl_deep_extend('force', global_defaults, source_defaults, opts or {})

    ---@class PWSource : Source
    local PWSource = {
        opts = opts,
    }

    function PWSource:cmd()
        local source = self.opts.source
        local verbose = (self.opts.verbose and '-v') or ''

        return string.format('pw-record --rate %d --channels %d --format %s --volume %f %s %s -', self.opts.sample_rate,
            self.opts.channels, source.format, source.volume, verbose, source.custom_options)
    end

    function PWSource.name()
        return 'Pipewire'
    end

    return PWSource
end

return M

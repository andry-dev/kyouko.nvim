local global_defaults = require('kyouko.defaults')

local M = {}

--- Generates an Opus encoder.
--- This requires `opusenc` installed.
local encoder_defaults = {
    encoder = {
        bitrate = 128,
        raw_input = true,
    }
}

function M.new(opts)
    opts = vim.tbl_deep_extend('force', global_defaults, encoder_defaults, opts or {})

    ---@class OpusEncoder : Encoder
    local OpusEncoder = {
        opts = opts
    }

    function OpusEncoder:cmd(filename)
        local enc = self.opts.encoder
        local raw = (enc.raw_input and '--raw') or ''

        return string.format('opusenc --bitrate %d %s --raw-chan %d --raw-rate %d - %s', enc.bitrate, raw,
            self.opts.channels, self.opts.sample_rate,
            filename)
    end

    function OpusEncoder.name()
        return 'Opus'
    end

    return OpusEncoder
end

return M

---@module 'kyouko'
---@author andry-dev
---@license GPL-3.0

local Job = require('plenary.job')

local default_dir = '.recordings/'

---@enum RecordingStatus
local RecordingStatus = {
    Stopped = 0,
    Started = 1
}

---@class Kyouko
---@field private _status RecordingStatus
---@field private _buffer table|nil
---@field private _start_timestamp integer
---@field private _jobs table
local M = {
    _buffer = nil,
    _status = RecordingStatus.Stopped,
    _start_timestamp = 0,
    _jobs = {
        shell = nil,
        -- record = nil,
        -- convert = nil
    }
}

local function autogenerate_name()
    return os.date('%Y-%m-%d_%H:%M:%S')
end

function M:_create_new_buf(filename)
    if not self._buffer then
        local buf = vim.api.nvim_create_buf(true, false)
        self._buffer = {
            bufnr = buf,
            title = filename,
        }
    end


    vim.api.nvim_buf_set_name(self._buffer.bufnr, 'kyouko://' .. filename)
    vim.api.nvim_buf_set_option(self._buffer.bufnr, 'buftype', 'nofile')
    self._buffer.title = filename
end

function M:_write_to_buf(callback)
    if not self._buffer then
        return
    end

    vim.api.nvim_buf_set_option(self._buffer.bufnr, 'modifiable', true)
    callback(self._buffer.bufnr)
    vim.api.nvim_buf_set_option(self._buffer.bufnr, 'modifiable', false)
end

function M:_new_job(filename)
    if self._status == RecordingStatus.Started then
        return
    end

    -- FIXME: Plenary removes \r from the input, which results in garbled data
    --        This hack spawns a shell to encode the file
    self._jobs.shell = Job:new({
        command = 'sh',
        args = {
            '-c',
            'pw-record - | opusenc --raw - ' .. filename
        },
        on_stdout = vim.schedule_wrap(function(_, data, _)
            M:_write_to_buf(function(buf)
                vim.api.nvim_buf_set_lines(buf, -1, -1, true, { data })
            end)
        end),
        -- on_stderr = vim.schedule_wrap(function(_, data, _)
        --     local lines = vim.split(data, '\n', { trimempty = true })
        --     vim.pretty_print(lines)
        --     M:_write_to_buf(function(buf)
        --         vim.api.nvim_buf_set_lines(buf, -1, -1, true, lines)
        --     end)
        -- end),
        on_exit = vim.schedule_wrap(function(_, _)
            M:_write_to_buf(function(buf)
                local output = string.format('Recording "%s" finished!', self._buffer.title)
                vim.api.nvim_buf_set_lines(buf, -1, -1, true, { output })
            end)
        end)
    })
    --
    -- self.jobs.convert = Job:new({
    --     command = 'opusenc',
    --     args = { '--raw', '-', filename },
    --     on_stdout = vim.schedule_wrap(function(_, data, _)
    --         M:_write_to_buf(function(buf)
    --             vim.api.nvim_buf_set_lines(buf, -1, -1, true, { data })
    --         end)
    --     end),
    --     on_stderr = vim.schedule_wrap(function(_, data, _)
    --         local lines = vim.split(data, '\n', { trimempty = true })
    --         vim.pretty_print(lines)
    --         M:_write_to_buf(function(buf)
    --             vim.api.nvim_buf_set_lines(buf, -1, -1, true, lines)
    --         end)
    --     end),
    --     on_exit = vim.schedule_wrap(function(_, _)
    --         M:_write_to_buf(function(buf)
    --             local output = string.format('Recording "%s" finished!', self.buffer.title)
    --             vim.api.nvim_buf_set_lines(buf, -1, -1, true, { output })
    --         end)
    --
    --         self.jobs.record:shutdown()
    --     end)
    -- })
    --
    -- self.jobs.record = Job:new({
    --     command = 'pw-record',
    --     args = { '-' },
    --     on_stdout = vim.schedule_wrap(function(_, data, _)
    --         self.jobs.convert:send(data)
    --     end),
    -- })
end

--- Starts a new recording. It will be placed inside the .recordings directory
--- inside the current working directory.
---@param name? string The name of the recording.
---If not provided it will be autogenerated as an ISO date (yy-mm-dd-HH:MM:SS).
function M:new_recording(name)
    if self._status == RecordingStatus.Started then
        print("Kyouko: Already recording!")
        return
    end

    local recording_name = name or autogenerate_name()

    local filename = default_dir .. recording_name .. '.ogg'

    vim.fn.mkdir(default_dir, 'p')

    M:_create_new_buf(recording_name)
    M:_new_job(filename)

    self._jobs.shell:start()
    self._start_timestamp = os.time()

    self._status = RecordingStatus.Started
    M:_write_to_buf(function(buf)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Recording to " .. filename })
    end)

    -- vim.cmd.buffer(self.buffer.bufnr)
end

--- Stop the current recording.
--- Does nothing if no recording is taking place.
function M:stop_recording()
    if self._status == RecordingStatus.Stopped then
        return
    end

    self._jobs.shell:shutdown()
    self._status = RecordingStatus.Stopped
end

--- Insert the current timestamp of the recording at cursor position.
--- The timestamp is _always_ of the form hh:mm:ss and it cannot be changed.
---
--- This functions returns early if there is no recording in place.
---
---@param opts { format: string, insert_text: boolean } A table with the following keys:
---   - format:
---     The format string to use for appending the timestamp.
---     Default: ' [%s] ' ( e.g. ' [00:05:23] ').
---     Please not that this is _not_ the "format of the timestamp"!
---     This parameter is useful if you need to personalize the string that is
---       inserted without rewriting the entire function.
---
---   - insert_text:
---     Whether to actually insert the timestamp in the current buffer.
---     If false, this function just returns the formatted timestamp according
---       to opts.format.
---     Default: true
---@see string.format
---@return string | nil timestamp The formatted timestamp on success, nil on failure.
function M:annotate(opts)
    if self._status ~= RecordingStatus.Started then
        return
    end

    opts = opts or {}
    local default_opts = {
        format = ' [%s] ',
        insert_text = true
    }

    opts = vim.tbl_extend('force', default_opts, opts)


    local diff = os.difftime(os.time(), self._start_timestamp)
    local timestamp = os.date('!%T', diff)

    if opts.insert_text then
        local cursor = vim.api.nvim_win_get_cursor(0)
        local line = string.format(opts.format, timestamp)
        vim.api.nvim_buf_set_text(0, cursor[1] - 1, cursor[2], cursor[1] - 1, cursor[2], { line })
        local new_cursor = vim.api.nvim_win_get_cursor(0)
        new_cursor[2] = new_cursor[2] + line:len() + 1
        vim.api.nvim_win_set_cursor(0, { new_cursor[1], new_cursor[2] + 1 })
        -- local mode = vim.api.nvim_get_mode()
        -- if mode.mode == 'n' then
        --     vim.cmd.normal('2W')
        -- elseif mode.mode == 'i' then
        --     vim.cmd [[normal! 2W2l]]
        -- end
    end

    return timestamp
end

--- Check if a recording is taking place.
---
---@return RecordingStatus status Enum which represent the current status of the recording.
function M:running()
    return self._status
end

--- Gets the title of the recording
---
---@return string|nil title The title of the current recording or nil if not recording.
function M:recording_title()
    if self._buffer then
        return self._buffer.title
    end

    return nil
end

local function setup_commands()
    vim.api.nvim_create_user_command('Kyouko', function(opt)
        -- vim.pretty_print(opt)
        if #opt.fargs == 0 then
            return
        end

        if opt.fargs[1] == 'start' then
            M:new_recording()
        elseif opt.fargs[1] == 'stop' then
            M:stop_recording()
        elseif opt.fargs[1] == 'annotate' then
            M:annotate()
        end
    end, {
        nargs = '*',
        force = true,
        complete = function(arglead, cmdline, cursorpos)
            return { "start", "stop", "annotate" }
        end,
    })
end

setup_commands()

return M

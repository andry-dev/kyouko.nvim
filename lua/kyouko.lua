local Job = require('plenary.job')

local default_dir = '.recordings/'

local RecordingStatus = {
    Stopped = 0,
    Started = 1
}

local M = {
    buffer = nil,
    status = RecordingStatus.Stopped,
    start_timestamp = 0,
    jobs = {
        shell = nil,
        -- record = nil,
        -- convert = nil
    }
}

local function autogenerate_name()
    return os.date('%Y-%m-%d_%H:%M:%S')
end

function M:_create_new_buf(filename)
    if not self.buffer then
        local buf = vim.api.nvim_create_buf(true, false)
        self.buffer = {
            bufnr = buf,
            title = filename,
        }
    end


    vim.api.nvim_buf_set_name(self.buffer.bufnr, 'kyouko://' .. filename)
    vim.api.nvim_buf_set_option(self.buffer.bufnr, 'buftype', 'nofile')
    self.buffer.title = filename
end

function M:_write_to_buf(callback)
    if not self.buffer then
        return
    end

    vim.api.nvim_buf_set_option(self.buffer.bufnr, 'modifiable', true)
    callback(self.buffer.bufnr)
    vim.api.nvim_buf_set_option(self.buffer.bufnr, 'modifiable', false)
end

function M:_new_job(filename)
    if self.status == RecordingStatus.Started then
        return
    end

    -- FIXME: Plenary removes \r from the input, which results in garbled data
    --        This hack spawns a shell to encode the file
    self.jobs.shell = Job:new({
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
                local output = string.format('Recording "%s" finished!', self.buffer.title)
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

function M:new_recording(name)
    if self.status == RecordingStatus.Started then
        print("Kyouko: Already recording!")
        return
    end

    local recording_name = name or autogenerate_name()

    local filename = default_dir .. recording_name .. '.ogg'

    vim.fn.mkdir(default_dir, 'p')

    M:_create_new_buf(recording_name)
    M:_new_job(filename)

    self.jobs.shell:start()
    self.start_timestamp = os.time()

    self.status = RecordingStatus.Started
    M:_write_to_buf(function(buf)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Recording to " .. filename })
    end)

    -- vim.cmd.buffer(self.buffer.bufnr)
end

function M:stop_recording()
    if self.status == RecordingStatus.Stopped then
        return
    end

    self.jobs.shell:shutdown()
    self.status = RecordingStatus.Stopped
end

function M:annotate(opts)
    if self.status ~= RecordingStatus.Started then
        return
    end

    local opts = opts or {
            format = ' [%s] ',
            insert_text = true
        }

    local diff = os.difftime(os.time(), self.start_timestamp)
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

function M:running()
    return self.status
end

function M:recording_title()
    if self.buffer then
        return self.buffer.title
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

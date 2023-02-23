# 🎤 Kyouko

Pre-alpha plugin to record lectures from within Neovim.

This plugin allows you to record audio from your microphone from within Neovim
and also insert the current timestamp of the recording inside a buffer.
A typical use-case is for taking notes for a lecture: maybe you want to record
the lecture but you don't want to guess where a passage is in the audio file.
With Kyouko you can annotate where exactly a phrase in the lecture was said, so
it's easier to find later on.

## Requirements

Right now only works with Linux (Pipewire) and with `opus-tools` installed
(needs `opusenc`).

This plugin uses Plenary's Job API, so you need [plenary.nvim](nvim-lua/plenary.nvim) installed.

## Installation

For [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    'andry-dev/kyouko.nvim',
    dependencies = {
        'nvim-lua/plenary.nvim'
    }
}
```

For [Packer](https://github.com/wbthomason/packer.nvim):

```lua
use {
    'andry-dev/kyouko.nvim',
    requires = {
        'nvim-lua/plenary.nvim'
    }
}
```

And you're done! Just use one of the subcommands of `:Kyouko`:

 - `:Kyouko start` starts recording from your main microphone.
   The recording is saved inside a `.recordings/` directory in the current
   working directory. The name of the file is generated from the current ISO
   date and time and its extension is OGG (Opus/Vorbis).

   A buffer will be created with URI `kyouko://` where you can see some
   info about the recording.

   From Lua: `require('kyouko'):new_recording()`.
 - `:Kyouko annotate` adds the current timestamp at the cursor position.
   This is useful when taking lecture notes to know where in the recording a
   passage was said.

   From Lua: `require('kyouko'):annotate()`.
 - `:Kyouko stop` stops the current recording.

   This does not close the `kyouko://` buffer.

   From Lua: `require('kyouko'):stop_recording()`.

## TODO

 - [ ] Make it customizable.
 - [ ] Support other sound servers.
 - [ ] Support other operating systems.
 - [ ] Keep track of the various recordings.

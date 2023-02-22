# 🎤 Kyouko

A pre-alpha Neovim plugin to record lectures from within Neovim and keep track of their timestamps.

## Requirements

Right now only works with Linux (Pipewire) with `opus-tools` installed (needs `opusenc`).

## Installation

Packer:

```lua
use { 'andry-dev/kyouko.nvim' }
```

lazy.nvim:

```lua
{ 'andry-dev/kyouko.nvim' }
```

And you're done! Just use one of the subcommands of `:Kyouko`:

 - `:Kyouko start` starts recording from your main microphone.
   The recording is saved inside a `.recordings/` directory in the current
   working directory. The name of the file is generated the current ISO date
   and time and its extension is OGG (Opus/Vorbis).

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

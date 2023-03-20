# 🤺 tabs-vs-spaces.nvim

Hint and fix deviating indentation.

<br>

https://user-images.githubusercontent.com/34311583/226349494-edd8da2a-f533-404a-956c-93e0318674d7.mov

<br>

Ideally, leading and trailing space are taken care of by a project-specific formatter. This plugin exists because despite that, commits and codebases continue to exist with indentation styles that differ from a project’s defaults.

There are several reasons why indentation styles might get mixed up.

- A project specific linter/formatter is not installed or in its necessary configuration available.
- Wrong indentation might not be obvious, with or without space chars toggled on.
- Quick editing single files outside a projects working directory.
- The editor is not configured to or did not automatically detect a files' indentation style.
- Reusing code templates from previous projects or copying code from external sources.
- Interference with local formatter settings.

For all these and similar occasions, this tool shall serve as a guide.

## Installation

E.g., using a plugin manager like [packer.nvim][10]

```lua
use "tenxsoydev/tabs-vs-spaces.nvim"

-- ..
-- Then load it in a preferred location.
require("tabs-vs-spaces").setup()
```

When using [lazy.nvim][20] it suffices to add this line to your `lazy.setup()` to use the plugin with it's default config.

```lua
{ "tenxsoydev/tabs-vs-spaces.nvim", config = true },
```

## ⚙️ Config

```lua
require("tabs-vs-spaces").setup {
  -- Preferred indentation. Possible values: "auto"|"tabs"|"spaces".
  -- "auto" detects the dominant indentation style in a buffer and highlights deviations.
  indentation = "auto",
  -- Use a string like "DiagnosticUnderlineError" to link the `TabsVsSpace` highlight to another highlight.
  -- Or a table valid for `nvim_set_hl` - e.g. { fg = "MediumSlateBlue", undercurl = true }.
  highlight = "DiagnosticUnderlineHint",
  -- Priority of highight matches.
  priority = 20,
  ignore = {
    filetypes = {},
    -- Works for normal buffers by default.
    buftypes = {
      "acwrite",
      "help",
      "nofile",
      "nowrite",
      "quickfix",
      "terminal",
      "prompt",
    },
  },
  standartize_on_save = false,
  -- Enable or disable user commands see Readme.md/#Commands for more info.
  user_commands = true,
}
```

## &nbsp;›&nbsp; Commands

- `:TabsVsSpacesToggle` optional args `on` | `buf_on` | `off` | `buff_off`
- `:TabsVsSpacesStandartize` works for current buffer or selected range `:'<,'>TabsVsSpacesStandartize`
- `:TabsVsSpacesConvert` args `spaces_to_tabs` | `tabs_to_spaces` for current buffer or range.

Command args work with completion.

## 🤝 Complementary Tools

- [mini.trailspace][30]
- [guess-indent][40]

[10]: https://github.com/wbthomason/packer.nvim
[20]: https://github.com/folke/lazy.nvim
[30]: https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-trailspace.md
[40]: https://github.com/nmac427/guess-indent.nvim

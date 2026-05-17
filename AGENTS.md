# Agent Guidelines for Assistant KOReader Plugin

## Project Overview

KOReader plugin written in Lua providing AI features (translation, summarization, X-Ray, recap, dictionary). Supports OpenAI, Anthropic, Gemini, DeepSeek, Ollama, and other providers via OpenAI-compatible APIs.

**Key directories:**
- `api_handlers/` - AI provider implementations (inherit `BaseHandler`)
- `l10n/` - Gettext `.po` translation files (one per language)
- Root: `main.lua` (entry point), `assistant_*.lua` (core modules)

**Entry point:** `main.lua` defines `Assistant` class (extends `InputContainer`), registers dispatcher actions, menu items, highlight dialog buttons, and event handlers.

## Build, Lint, and Test Commands

**No automated build/lint/test infrastructure.** The plugin is copied into KOReader's `plugins/` directory.

### Running the Plugin
```bash
cp -r assistant.koplugin /path/to/koreader/plugins/
```
```bash
cp configuration.sample.lua configuration.lua  # then edit with API keys
```

### Syntax Check
```bash
luac -p file.lua        # single file
luac -p *.lua           # all files in dir
luac -p api_handlers/*.lua && luac -p assistant_*.lua && luac -p main.lua  # full check
```

### CI/CD
GitHub Actions (`.github/workflows/release.yml`): on tag push `v*`, updates `_meta.lua` version, zips plugin (excludes hidden, `*.md`, keeps only `.po` in `l10n/`), creates prerelease.

### Testing
Manual only: open a book in KOReader, select text, use AI features.

---

## Code Style Guidelines

### Indentation
**2-space indentation** in most `assistant_*.lua` and `main.lua`. Some `api_handlers/*.lua` and utility files use 4-space. Prefer 2-space for new code.

### Imports (order: KOReader core → UI widgets → ffi → plugin modules)
```lua
local Device = require("device")
local logger = require("logger")
local UIManager = require("ui/uimanager")
local InputContainer = require("ui/widget/container/inputcontainer")
local NetworkMgr = require("ui/network/manager")
local T = require("ffi/util").template
local ffiutil = require("ffi/util")
local _ = require("assistant_gettext")
local AssistantDialog = require("assistant_dialog")
```

### Module Patterns

**Class definition** (two patterns coexist):
```lua
-- Pattern A: KOReader widget style (preferred for new widgets)
local Assistant = InputContainer:new {
  name = "assistant",
  is_doc_only = true,
}

-- Pattern B: Manual metatable (internal modules)
local Querier = { assistant = nil }
function Querier:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end
```

**Constructor** using `local self = setmetatable({}, Class)`:
```lua
function AssistantDialog:new(assistant, c)
  local self = setmetatable({}, AssistantDialog)
  self.assistant = assistant
  return self
end
```

### Naming Conventions
- **Files**: `lowercase_with_underscores.lua` (e.g., `assistant_utils.lua`)
- **Classes**: `CamelCase` (e.g., `AssistantDialog`, `BaseHandler`)
- **Functions**: `lowercase_with_underscores` for utilities, `CamelCase` for methods
- **Constants**: `UPPER_CASE` (e.g., `CODE_CANCELLED`, `CODE_NETWORK_ERROR`)
- **Variables**: `lowercase_with_underscores`
- **Callbacks**: `onEventName`, `callback`, `done_callback`

### Error Handling
```lua
local ok, result = pcall(function() return dofile(CONFIG_FILE_PATH) end)
if ok then CONFIGURATION = result else logger.warn(result) end
return false, "error message"
UIManager:show(InfoMessage:new{ icon = "notice-warning", text = err })
```
- Use `koutil.tableGetValue(CONFIG, "features", "key") or default` for safe nested access

### String Handling
```lua
local _ = require("assistant_gettext")
T(_("Hello %1"), name)        -- template placeholders: %1, %2, ...
N_("item", "items", count)    -- pluralization
string.format("%.2f", val)
```

### API Handlers
Each provider extends `BaseHandler` (`api_handlers/base.lua`):
```lua
local BaseHandler = require("api_handlers.base")
local Handler = BaseHandler:new { name = "myprovider" }
function Handler:query(message_history, provider_setting)
  -- returns (content, error_message)
end
```
- `self:makeRequest(url, headers, body, timeout, maxtime)` for blocking requests
- `self:backgroundRequest(url, headers, body)` for subprocess streaming
- Error codes: `BaseHandler.CODE_CANCELLED`, `BaseHandler.CODE_NETWORK_ERROR`

### UI Development
- Use KOReader widgets: `Button`, `TextViewer`, `ConfirmBox`, `InputDialog`, `InfoMessage`, `ButtonTable`, `TitleBar`
- Wrap long operations: `Trapper:wrap()` for progress/cancel dialogs
- Network: `NetworkMgr:runWhenOnline(function() ... end)`
- Display: `UIManager:show(widget)`
- Defer execution: `UIManager:nextTick(function() ... end)`
- Markdown rendering: enabled via `CONFIGURATION.features.render_markdown = true`

### Logging
- Use `logger.warn()` (never `logger.info()`) for non-critical issues
- NEVER log API keys or user text content

### Custom Prompts
Defined in `configuration.lua` under `features.prompts`. Each prompt has: `text`, `system_prompt`, `user_prompt`, `order`, `show_on_main_popup`, `loading_message`, `use_book_text`, `use_highlight_with_notebook`, `use_highlight_without_notebook`

### Events
```lua
Event:new("EventName")
UIManager:broadcastEvent(Event:new("EventName"))
-- Handler: function Assistant:onEventName() ... end
```

## Configuration

User config in `configuration.lua` (gitignored). NEVER commit API keys. Use `configuration.sample.lua` as template. The plugin validates config at startup via `testConfigFile()` in `main.lua`. Errors show as warning dialogs.

-------------------------------------------------------------------------------
-- Settings
local LAYERTAP_TIMEOUT = 200 -- ms
local OPENING_ALERT_DURATION = 0.5 -- seconds
local KEY_DEBOUNCE_THRESHOLD = 0.075 -- seconds

-------------------------------------------------------------------------------
-- Key Mode and Debounce Setup
local keyPressed, keyPressedTime, modalActive, keyDebounceTime = {}, {}, {}, {}
for _, k in ipairs({"f13", "f14", "f15"}) do
    keyPressed[k] = false
    keyPressedTime[k] = 0
    modalActive[k] = false
end

local keyCodes = {
    f13 = 0x69, f14 = 0x6B, f15 = 0x71,
    right_command = 0x36, right_option = 0x3D
}

local f13Mode = hs.hotkey.modal.new()
local f14Mode = hs.hotkey.modal.new()
local f15Mode = hs.hotkey.modal.new()

-------------------------------------------------------------------------------
-- Helpers
function openingAlert(app)
    if OPENING_ALERT_DURATION == 0 then return end
    local name = app:match("/([^/]+)%.app$") or app:match("([^/]+)%.app$") or app
    hs.alert.showWithImage("Opening " .. name, nil, hs.screen.mainScreen(), OPENING_ALERT_DURATION)
end

function launcher(mode, mods, key, app, args)
    local m = ({f13 = f13Mode, f14 = f14Mode, f15 = f15Mode})[mode]
    if not m then return end
    m:bind(mods, key, function()
        openingAlert(app)
        if args and #args > 0 then
            local cmd = "open -a '" .. app .. "'"
            for _, arg in ipairs(args) do
                cmd = cmd .. " --args '" .. arg .. "'"
            end
            hs.execute(cmd)
        else
            hs.application.launchOrFocus(app)
        end
        modalActive[mode] = true
        m:exit()
    end)
end

-------------------------------------------------------------------------------
-- Keystroke helper: supports optional exit or repeat
-- usage: keystroke(mode, mods, inputKey, outputMods, outputKey, exitOnPress)
--   exitOnPress: boolean (default=true) – if false, modal stays active
function keystroke(mode, mods, inputKey, outputMods, outputKey, exitOnPress)
    exitOnPress = (exitOnPress == nil) and true or exitOnPress
    local m = ({ f13 = f13Mode, f14 = f14Mode, f15 = f15Mode })[mode]
    if not m then return end

    -- pressedFn
    local function handlePress()
        hs.eventtap.keyStroke(outputMods, outputKey)
        modalActive[mode] = true
        if exitOnPress then m:exit() end
    end

    -- repeatFn (only called if the key is held)
    local function handleRepeat()
        if not exitOnPress then
            hs.eventtap.keyStroke(outputMods, outputKey)
        end
    end

    -- bind with pressed, no release, and repeat
    m:bind(mods, inputKey, handlePress, nil, handleRepeat)
end

-- Text‑insertion macros (static or dynamic)
-- usage: textMacro(mode, mods, key, content)
--   content: either a string or a function that returns a string
function textMacro(mode, mods, key, content)
    local m = ({f13 = f13Mode, f14 = f14Mode, f15 = f15Mode})[mode]
    if not m then return end

    m:bind(mods, key, function()
        local original = hs.pasteboard.getContents()
        local toPaste = (type(content) == "function" and content()) or content
        hs.pasteboard.setContents(toPaste)
        hs.eventtap.keyStroke({"cmd"}, "v")
        hs.timer.doAfter(0.1, function()
            hs.pasteboard.setContents(original)
        end)
        modalActive[mode] = true
        m:exit()
    end)
end

-------------------------------------------------------------------------------
-- Eventtap for Layer Tap + Debounce
keyWatcher = hs.eventtap.new({hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp}, function(event)
    local code = event:getKeyCode()
    local type = event:getType()
    local keyName = nil

    for name, val in pairs(keyCodes) do
        if val == code then keyName = name break end
    end
    if not keyName then return false end

    local now = hs.timer.secondsSinceEpoch()
    if type == hs.eventtap.event.types.keyDown then
        if keyDebounceTime[keyName] and (now - keyDebounceTime[keyName]) < KEY_DEBOUNCE_THRESHOLD then
            return true
        end
        keyDebounceTime[keyName] = now
        keyPressed[keyName] = true
        keyPressedTime[keyName] = now
        if keyName == "f13" then f13Mode:enter()
        elseif keyName == "f14" then f14Mode:enter()
        elseif keyName == "f15" then f15Mode:enter() end
        return true
    elseif type == hs.eventtap.event.types.keyUp then
        local held = (now - keyPressedTime[keyName]) * 1000
        keyPressed[keyName] = false
        if keyName == "f13" then
            f13Mode:exit()
            if held < LAYERTAP_TIMEOUT and not modalActive.f13 then hs.eventtap.keyStroke({}, "escape") end
            modalActive.f13 = false
        elseif keyName == "f14" then
            f14Mode:exit()
            if held < LAYERTAP_TIMEOUT and not modalActive.f14 then hs.eventtap.keyStroke({}, keyCodes.right_command) end
            modalActive.f14 = false
        elseif keyName == "f15" then
            f15Mode:exit()
            if held < LAYERTAP_TIMEOUT and not modalActive.f15 then hs.eventtap.keyStroke({}, keyCodes.right_option) end
            modalActive.f15 = false
        end
        return true
    end

    return false
end)

-------------------------------------------------------------------------------
-- Application Launchers
launcher("f13", {}, "t", "/Applications/iTerm2.app")
launcher("f13", {}, "o", "/Applications/1Password.app")
launcher("f13", {}, "w", "/Applications/Firefox.app")
launcher("f13", {}, "`", "/Applications/UpNote.app")
launcher("f13", {}, "1", "/Applications/Telegram.app")
launcher("f13", {}, "2", "/Applications/Discord.app")
launcher("f13", {}, "3", "/Applications/Signal.app")
launcher("f13", {}, "4", "/Applications/FaceTime.app")

f13Mode:bind({}, 'e', function()
    openingAlert("Finder")
    hs.application.launchOrFocus("Finder")
    hs.timer.doAfter(0.1, function()
        hs.eventtap.keyStroke({"cmd", "shift"}, "h")
    end)
    modalActive.f13 = true
    f13Mode:exit()
end)

launcher("f14", {}, ",", "/Applications/Firefox.app", {"--new-tab", "kagi.com"})

-------------------------------------------------------------------------------
-- Key Remaps
keystroke("f13", {}, "left",  {}, "home", false)
keystroke("f13", {}, "right", {}, "end", false)
keystroke("f13", {}, "up",    {}, "pageup", false)
keystroke("f13", {}, "down",  {}, "pagedown", false)

-------------------------------------------------------------------------------
-- Text Macros
textMacro("f14", {}, "s", function()
    return "--EY:" .. os.date("%Y-%m-%d")
end)
textMacro("f14", {}, "d", function()
    return os.date("%Y-%m-%d")
end)
textMacro("f14", {}, "t", function()
    return os.date("%Y-%m-%d %I:%M:%S %p")
end)
textMacro("f14", {}, "i", function()
    return os.date("%Y-%m-%dT%H:%M:%SZ")
end)
f14Mode:bind({}, "n", function() -- "Now" for my Excel sheets (Date in A, Time in B)
    local d = os.date("%Y-%m-%d")
    local t = os.date("%H:%M")
    hs.eventtap.keyStrokes(d)
    hs.eventtap.keyStroke({}, "tab")
    hs.eventtap.keyStrokes(t)
    hs.eventtap.keyStroke({}, "tab")
    modalActive.f14 = true
    f14Mode:exit()
end)

-------------------------------------------------------------------------------
-- URL Cleaner
local urlHandlers = {
    {
        name = "Bluesky",
        match = function(url) return url:match("bsky%.app") end,
        transform = function(url)
            return url:gsub("^https?://[www%.]*bsky%.app", "https://fxbsky.app")
        end
    },
    {
        name = "Twitter/X",
        match = function(url)
            return url:match("^https?://[www%.]*x%.com")
                or url:match("^https?://[www%.]*twitter%.com")
        end,
        transform = function(url)
            return url:gsub("^https?://[www%.]*[xtwitter]+%.com/(.*)$", "https://fxtwitter.com/%1")
        end
    },
    {
        name = "YouTube",
        match = function(url) return url:match("youtube%.com/watch%?v=([^&]+)") end,
        transform = function(url)
            local videoId = url:match("v=([^&]+)")
            return videoId and ("https://youtu.be/" .. videoId) or url
        end
    },
    {
        name = "Amazon",
        match = function(url)
            return url:match("^https?://[www%.]*amazon%.([%w%.]+)")
        end,
        transform = function(url)
            local pid = url:match("/dp/([A-Z0-9]+)")
                        or url:match("/gp/product/([A-Z0-9]+)")
            local domain = url:match("^https?://[www%.]*amazon%.([%w%.]+)") or "com"
            if pid then
                return string.format("https://amazon.%s/dp/%s", domain, pid)
            end
            return url:gsub("%?.*$", ""):gsub("/+$", "")
        end
    },
    -- Filthy degeneracy
    {
        name = "e621",
        match = function(url) return url:match("e621%.net") end,
        transform = function(url) return url:gsub("%?.*$", "") end
    },
    {
        name = "FurAffinity",
        match = function(url) return url:match("furaffinity%.net") end,
        transform = function(url)
            return url:gsub("^https?://[www%.]*furaffinity%.net", "https://fxfuraffinity.net")
        end
    },
}

f13Mode:bind({}, 'v', function()
    local clipboard = hs.pasteboard.getContents()
    local original = clipboard
    local cleanUrl, modified

    if not clipboard or not clipboard:match("^https?://") then
        hs.alert.show("Clipboard doesn't contain a valid URL")
        f13Mode:exit()
        return
    end

    for _, handler in ipairs(urlHandlers) do
        if handler.match(clipboard) then
            cleanUrl = handler.transform(clipboard)
            break
        end
    end
    cleanUrl = cleanUrl or clipboard:gsub("%?.*$", ""):gsub("/+$", "")

    if cleanUrl ~= original then
        hs.pasteboard.setContents(cleanUrl)
        modified = true
    end

    if modified then
        hs.timer.doAfter(0.1, function()
            local app = hs.application.frontmostApplication()
            if app then app:activate() hs.eventtap.keyStroke({"cmd"}, "v") end
        end)
    end

    modalActive.f13 = true
    f13Mode:exit()
end)

-------------------------------------------------------------------------------
-- hidutil Remap
local remap = {
    { HIDKeyboardModifierMappingSrc = 0x700000039, HIDKeyboardModifierMappingDst = 0x700000068 }, -- Caps → F13
    { HIDKeyboardModifierMappingSrc = 0x7000000e7, HIDKeyboardModifierMappingDst = 0x700000069 }, -- RCmd → F14
    { HIDKeyboardModifierMappingSrc = 0x7000000e6, HIDKeyboardModifierMappingDst = 0x70000006A }  -- ROpt → F15
}
local json = hs.json.encode(remap)
local command = "hidutil property --set '" .. '{"UserKeyMapping": ' .. json .. "}'"
hs.task.new("/bin/zsh", nil, function() return false end, {"-c", command}):start()

-- Manual Remap Reset Hotkey
local lastResetTime = 0
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "R", function()
    local now = hs.timer.absoluteTime() / 1e9
    if now - lastResetTime < 2 then hs.alert("Wait a sec…", 0.5) return end
    lastResetTime = now
    hs.task.new("/bin/zsh", nil, function() return false end,
        {"-c", "hidutil property --set '{\"UserKeyMapping\": []}'"}):start()
    hs.alert("Key remaps cleared.")
end)

-------------------------------------------------------------------------------
-- Start Watcher
keyWatcher:start()
hs.alert("Config loaded.")

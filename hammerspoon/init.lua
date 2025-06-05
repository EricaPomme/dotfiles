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

function launcher(mode, mods, key, app)
    local m = ({f13 = f13Mode, f14 = f14Mode, f15 = f15Mode})[mode]
    if not m then return end
    m:bind(mods, key, function()
        openingAlert(app)
        hs.application.launchOrFocus(app)
        modalActive[mode] = true
        m:exit()
    end)
end

function text(mode, mods, key, str)
    local m = ({f13 = f13Mode, f14 = f14Mode, f15 = f15Mode})[mode]
    if not m then return end
    m:bind(mods, key, function()
        local original = hs.pasteboard.getContents()
        hs.pasteboard.setContents(str)
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
launcher("f13", {}, "t", "/Applications/Warp.app")
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

-------------------------------------------------------------------------------
-- Text Macros

-- Signature
f14Mode:bind({}, "s", function()
    local original = hs.pasteboard.getContents()
    hs.pasteboard.setContents("--EY:" .. os.date("%Y-%m-%d"))
    hs.eventtap.keyStroke({"cmd"}, "v")
    hs.timer.doAfter(0.1, function()
        hs.pasteboard.setContents(original)
    end)
    modalActive.f14 = true
    f14Mode:exit()
end)

-- Datestamp
f14Mode:bind({}, "d", function()
    local original = hs.pasteboard.getContents()
    hs.pasteboard.setContents(os.date("%Y-%m-%d"))
    hs.eventtap.keyStroke({"cmd"}, "v")
    hs.timer.doAfter(0.1, function()
        hs.pasteboard.setContents(original)
    end)
    modalActive.f14 = true
    f14Mode:exit()
end)

-- Timestamp (12-hour format)
f14Mode:bind({}, "t", function()
    local original = hs.pasteboard.getContents()
    hs.pasteboard.setContents(os.date("%Y-%m-%d %I:%M:%S %p"))
    hs.eventtap.keyStroke({"cmd"}, "v")
    hs.timer.doAfter(0.1, function()
        hs.pasteboard.setContents(original)
    end)
    modalActive.f14 = true
    f14Mode:exit()
end)

-- ISO8601 Timestamp
f14Mode:bind({}, "i", function()
    local original = hs.pasteboard.getContents()
    hs.pasteboard.setContents(os.date("%Y-%m-%dT%H:%M:%SZ"))
    hs.eventtap.keyStroke({"cmd"}, "v")
    hs.timer.doAfter(0.1, function()
        hs.pasteboard.setContents(original)
    end)
    modalActive.f14 = true
    f14Mode:exit()
end)

-------------------------------------------------------------------------------
-- URL Cleaner
f13Mode:bind({}, 'v', function()
    local clipboard = hs.pasteboard.getContents()
    local original = clipboard
    local cleanUrl, modified

    if clipboard:match("e621%.net") then
        cleanUrl = clipboard:gsub("%?.*$", "")
    elseif clipboard:match("^https?://[www%.]*[x|twitter]%.com") then
        cleanUrl = clipboard:gsub("^https?://[www%.]*[x|twitter]%.com/(.*)$", "https://fxtwitter.com/%1")
    elseif clipboard:match("^https?://[www%.]*youtube%.com/watch%?v=([^&]+)") then
        cleanUrl = "https://youtu.be/" .. clipboard:match("v=([^&]+)")
    elseif clipboard:match("^https?://[www%.]*amazon%.([%w%.]+)") then
        local pid = clipboard:match("/[dgp]+/product/([A-Z0-9]+)")
        if pid then
            local domain = clipboard:match("^https?://[www%.]*amazon%.([%w%.]+)") or "com"
            cleanUrl = string.format("https://amazon.%s/dp/%s", domain, pid)
        end
    elseif clipboard:match("furaffinity%.net") then
        cleanUrl = clipboard:gsub("^https?://[www%.]*furaffinity%.net", "https://fxfuraffinity.net")
    end

    cleanUrl = cleanUrl or clipboard:gsub("/ref=[^/%?]+", ""):gsub("%?.*$", "")
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

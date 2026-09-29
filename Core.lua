local ADDON_NAME, ns = ...
local L = ns.L

-- Init, AceDB, Events, Slash-Befehle

ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")) or "?"

ns.defaults = {
  profile = {
    alerts = {
      meta = { enabled = true, sound = ns.Sounds.DEFAULTS.meta },   -- Standard je nach Client-Sprache
      star = { enabled = true, sound = ns.Sounds.DEFAULTS.star },
    },
    channel = "Master",
    combatOnly = true,
    chatMessages = false,   -- Ladehinweis und Testmeldung im Chat (Fehlerhinweise immer)
  },
  global = {
    debug = false,
  },
}

local function Print(msg)
  print("|cff9d5cffVoidAlert|r: " .. msg)
end
ns.Print = Print

ns.inCombat = false

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local events = CreateFrame("Frame")
local handlers = {}

-- Spezialisierung neu prüfen (SPEC 3). Loggen nur, wenn sich etwas geändert hat,
-- denn SPELLS_CHANGED kommt oft.
local function checkSpec(why)
  if not ns.loggedIn then return end
  if ns.Alerts:Update() then
    ns.Alerts:LogSpec(why)
    ns.Options:Notify()   -- Hinweis oben im Menü (aktiv/inaktiv) nachziehen
  end
end

function handlers.ADDON_LOADED(name)
  if name ~= ADDON_NAME then return end
  events:UnregisterEvent("ADDON_LOADED")

  -- Ohne dritten Parameter legt AceDB ein Profil pro Charakter an ("Name - Realm").
  -- Ein Charakter, der in 1.0.0-beta.1 ein anderes Profil gewählt hat, behält es
  -- (AceDB liest sv.profileKeys[Charakter]).
  ns.db = LibStub("AceDB-3.0"):New("VoidAlertDB", ns.defaults)
  ns.Debug:Init()
  ns.Options:Init()
end

-- Bei ADDON_LOADED war GetSpecialization() im Test noch 0 (SPEC 3), darum erst hier
function handlers.PLAYER_LOGIN()
  ns.inCombat = InCombatLockdown() and true or false
  ns.Alerts:Init()
  ns.Alerts:Update()
  ns.loggedIn = true
  ns.Debug:LogMeta()
  ns.Alerts:LogSpec("login")
  -- Andere Klassen und Specs: Addon still (SPEC 3)
  if ns.Alerts.active and ns.db.profile.chatMessages then Print(L["LOADED"]:format(ns.VERSION)) end
end

function handlers.PLAYER_SPECIALIZATION_CHANGED(unit)
  if unit ~= nil and unit ~= "player" then return end
  checkSpec("specChanged")
end

function handlers.SPELLS_CHANGED()
  checkSpec("spellsChanged")
end

function handlers.PLAYER_REGEN_DISABLED()
  ns.inCombat = true
  ns.Debug:Add("combatStart", { active = ns.Alerts.active })
end

function handlers.PLAYER_REGEN_ENABLED()
  ns.inCombat = false
  ns.Debug:Add("combatEnd")
end

function handlers.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW(spellID)
  if not ns.loggedIn then return end
  ns.Alerts:OnGlowShow(spellID)
end

function handlers.SPELL_ACTIVATION_OVERLAY_GLOW_HIDE(spellID)
  if not ns.loggedIn then return end
  ns.Alerts:OnGlowHide(spellID)
end

events:SetScript("OnEvent", function(_, event, ...)
  local handler = handlers[event]
  if not handler then return end
  -- Vor ADDON_LOADED gibt es noch keine Datenbank
  if not ns.db and event ~= "ADDON_LOADED" then return end
  local ok, err = pcall(handler, ...)
  if not ok then
    if ns.db then ns.Debug:Error(event, err) end
    if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
      geterrorhandler()(err)
    end
  end
end)

for event in pairs(handlers) do
  local ok = pcall(events.RegisterEvent, events, event)
  if not ok then Print("Event unknown: " .. event) end
end

---------------------------------------------------------------------------
-- Slash-Befehle. /voidalert ohne Argument öffnet das Menü.
---------------------------------------------------------------------------

local ALERTS = { meta = true, star = true }

local function onOff(value)
  return value and L["ON"] or L["OFF"]
end

local function printHelp()
  Print(L["HELP_HEADER"])
  for _, key in ipairs({ "HELP_OPEN", "HELP_HELP", "HELP_STATUS", "HELP_TEST", "HELP_SOUNDS", "HELP_SOUND",
      "HELP_TOGGLE", "HELP_CHANNEL", "HELP_COMBAT", "HELP_DEBUG" }) do
    print("  " .. L[key])
  end
end

-- Nach jeder Änderung per Slash-Befehl ein offenes Menü aktualisieren
local function changed(setting)
  ns.Debug:Add("setting", setting)
  ns.Options:Notify()
end

local commands = {}

function commands.help()
  printHelp()
end

function commands.status()
  local A, p = ns.Alerts, ns.db.profile
  Print(L["STATUS_HEADER"]:format(ns.VERSION))
  local state = A.active and L["STATUS_ACTIVE"] or L["STATUS_INACTIVE"]
  print("  " .. L["STATUS_STATE"]:format(state, tostring(A.specName), tostring(A.specID), tostring(A.known)))
  for _, alert in ipairs(A.ORDER) do
    local a = p.alerts[alert]
    print("  " .. L["STATUS_ALERT"]:format(L["ALERT_" .. alert], onOff(a.enabled), ns.Sounds:Label(a.sound)))
  end
  print("  " .. L["STATUS_OPTIONS"]:format(L["CHANNEL_" .. p.channel], onOff(p.combatOnly), onOff(ns.Debug:IsEnabled())))
end

function commands.test(arg)
  if arg ~= "" and not ALERTS[arg] then printHelp(); return end
  ns.Alerts:Test(arg ~= "" and arg or nil)
end

function commands.sounds()
  Print(L["SOUNDS_HEADER"])
  for i, entry in ipairs(ns.Sounds:List()) do
    print(("  %d. %s"):format(i, entry.label))
  end
  print("  " .. L["SOUNDS_CUSTOM_NOTE"]:format(ns.Sounds.CUSTOM_FOLDER))
end

function commands.sound(arg)
  local alert, choice = arg:match("^(%S+)%s*(.-)$")
  if not ALERTS[alert] or choice == "" then printHelp(); return end
  local key
  if choice == "default" then
    key = ns.Sounds.DEFAULTS[alert]
  else
    local entry = ns.Sounds:List()[tonumber(choice) or 0]
    if not entry then
      Print(L["SOUND_UNKNOWN"])
      return
    end
    key = entry.key
  end
  ns.db.profile.alerts[alert].sound = key
  changed({ alert = alert, sound = key })
  Print(L["SOUND_SET"]:format(L["ALERT_" .. alert], ns.Sounds:Label(key)))
end

function commands.toggle(arg)
  if not ALERTS[arg] then printHelp(); return end
  local a = ns.db.profile.alerts[arg]
  a.enabled = not a.enabled
  changed({ alert = arg, enabled = a.enabled })
  Print(L["ALERT_TOGGLED"]:format(L["ALERT_" .. arg], onOff(a.enabled)))
end

function commands.channel(arg)
  for _, channel in ipairs(ns.Sounds.CHANNELS) do
    if channel:lower() == arg then
      ns.db.profile.channel = channel
      changed({ channel = channel })
      Print(L["CHANNEL_SET"]:format(L["CHANNEL_" .. channel]))
      return
    end
  end
  printHelp()
end

function commands.combat(arg)
  if arg ~= "on" and arg ~= "off" then printHelp(); return end
  ns.db.profile.combatOnly = arg == "on"
  changed({ combatOnly = ns.db.profile.combatOnly })
  Print(L["COMBAT_SET"]:format(onOff(ns.db.profile.combatOnly)))
end

function commands.debug(arg)
  if arg == "on" then
    ns.Debug:SetEnabled(true)
    ns.Alerts:LogSpec("debugOn")
    ns.Options:Notify()
    Print(L["DEBUG_ON"])
  elseif arg == "off" then
    ns.Debug:Add("debugOff")
    ns.Debug:SetEnabled(false)
    ns.Options:Notify()
    Print(L["DEBUG_OFF"])
  elseif arg == "clear" then
    ns.Debug:Clear()
    Print(L["DEBUG_CLEARED"])
  else
    Print(L["DEBUG_STATUS"]:format(onOff(ns.Debug:IsEnabled()), ns.Debug:Count()))
  end
end

SLASH_VOIDALERT1 = "/voidalert"
SlashCmdList.VOIDALERT = function(msg)
  if not ns.db or not ns.loggedIn then return end
  local cmd, arg = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
  cmd = cmd:lower()
  -- LSM-Namen können Großbuchstaben enthalten, werden aber per Nummer gewählt
  arg = arg:lower()
  if cmd == "" then
    -- Menü öffnen; ohne Menü (Bibliothek fehlt, Fehler) die Hilfe zeigen
    if not ns.Options:Open() then printHelp() end
  elseif commands[cmd] then
    local ok, err = pcall(commands[cmd], arg)
    if not ok then
      ns.Debug:Error("slash " .. cmd, err)
      geterrorhandler()(err)
    end
  else
    Print(L["UNKNOWN_COMMAND"])
  end
end

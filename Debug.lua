local ADDON_NAME, ns = ...

-- Debug-Log in der SavedVariable VoidAlertDebugLog (Ringpuffer), übernommen aus DotRange/OwnDPS.
-- Regel: Secret Values werden nie gespeichert, nur als "<SECRET>" markiert (SPEC 6).

local Debug = {}
ns.Debug = Debug

local MAX_ENTRIES = 5000
local ERROR_REPEAT_SECONDS = 5

local issecret = issecretvalue or function() return false end

local loginNo = 0
local lastErrors = {}   -- Meldungstext -> Zeitpunkt, drosselt identische Fehler

-- Wandelt einen Wert in etwas Speicherbares um. Secret Values -> "<SECRET>".
local function S(v)
  if issecret(v) then return "<SECRET>" end
  if v == nil then return "nil" end
  local t = type(v)
  if t == "number" or t == "string" or t == "boolean" then return v end
  return "<" .. t .. ">"
end
Debug.S = S

function Debug:Init()
  if type(VoidAlertDebugLog) ~= "table" then VoidAlertDebugLog = {} end
  local log = VoidAlertDebugLog
  if type(log.entries) ~= "table" then log.entries = {} end
  log.logins = (tonumber(log.logins) or 0) + 1
  loginNo = log.logins
end

function Debug:IsEnabled()
  return ns.db ~= nil and ns.db.global.debug == true
end

function Debug:SetEnabled(enabled)
  ns.db.global.debug = enabled and true or false
  if enabled then self:LogMeta() end
end

function Debug:Count()
  local log = VoidAlertDebugLog
  return (log and log.entries) and #log.entries or 0
end

function Debug:Clear()
  local log = VoidAlertDebugLog
  if log and log.entries then wipe(log.entries) end
end

-- data: flache Tabelle mit festen String-Schlüsseln; jeder Wert wird mit S() bereinigt.
function Debug:Add(kind, data)
  if not self:IsEnabled() then return end
  local log = VoidAlertDebugLog
  if not log or not log.entries then return end

  local entry = {}
  if data then
    for k, v in pairs(data) do entry[k] = S(v) end
  end
  entry.kind = kind
  entry.t = math.floor(GetTime() * 100 + 0.5) / 100
  entry.time = date("%H:%M:%S")
  entry.login = loginNo
  entry.combat = InCombatLockdown() and true or false

  local e = log.entries
  e[#e + 1] = entry
  while #e > MAX_ENTRIES do table.remove(e, 1) end
end

-- Fehler aus pcall. Gleiche Meldungen höchstens alle paar Sekunden.
function Debug:Error(where, err)
  if not self:IsEnabled() then return end
  local msg = S(err)
  if type(msg) ~= "string" then msg = tostring(msg) end
  local key = where .. ":" .. msg
  local now = GetTime()
  if lastErrors[key] and now - lastErrors[key] < ERROR_REPEAT_SECONDS then return end
  lastErrors[key] = now
  self:Add("error", { where = where, err = msg })
end

-- Version, Build, Sprache, Klasse, Spezialisierung, Einstellungen, Soundquellen (SPEC 6)
function Debug:LogMeta()
  if not self:IsEnabled() then return end
  local gameVersion, build, buildDate, toc = GetBuildInfo()
  local Alerts = ns.Alerts
  local specID, specName = Alerts:GetSpec()
  local p = ns.db.profile
  local out = {
    addonVersion = ns.VERSION,
    gameVersion = gameVersion, build = build, buildDate = buildDate, toc = toc,
    locale = GetLocale(),
    class = Alerts.class,
    specID = specID,
    specName = specName,
    voidMetaKnown = Alerts:IsKnown(Alerts.VOID_META_ID),
    active = Alerts.active,
    profile = ns.db:GetCurrentProfile(),
    metaEnabled = p.alerts.meta.enabled,
    metaSound = p.alerts.meta.sound,
    starEnabled = p.alerts.star.enabled,
    starSound = p.alerts.star.sound,
    channel = p.channel,
    combatOnly = p.combatOnly,
    chatMessages = p.chatMessages,
    hasIsSecretValue = issecretvalue ~= nil,
    hasIsSpellKnown = (C_SpellBook and C_SpellBook.IsSpellKnown) ~= nil,
    hasIsKnownFile = (C_UIFileAsset and C_UIFileAsset.IsKnownFile) ~= nil,
    hasLSM = ns.Sounds.LSM ~= nil,
  }
  self:Add("meta", out)
  self:Add("sounds", ns.Sounds:DebugInfo())
end

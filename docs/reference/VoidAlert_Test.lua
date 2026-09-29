-- VoidAlert_Test v0.1.0
-- Testaddon fuer den Daemonenjaeger (Verschlinger):
-- Findet heraus, welcher Weg im Kampf (Midnight) lesbar ist, um zu erkennen:
--   A) Leerenmetamorphose bereit (1217605)
--   B) Kollabierender Stern bereit (1221167)
-- Getestete Wege:
--   1. C_Spell.IsSpellUsable        (Wechsel nicht nutzbar -> nutzbar)
--   2. Aufleucht-Ereignis           (SPELL_ACTIVATION_OVERLAY_GLOW_SHOW)
--   3. C_Spell.GetSpellCastCount    (Zaehler auf dem Knopf, z. B. Seelenfragmente)
--   4. Eigene Buffs                 (Spell-ID, Name, Stapel geheim?)
--   5. Ressourcen (UnitPower)       (alle Typen mit "Soul"/"Fury"/"Void" im Namen)
-- Bei Erfolg von Weg 1 oder 2 wird sofort ein Sound gespielt und im Chat angezeigt.
--
-- Log: WTF\Account\<ACCOUNT>\SavedVariables\VoidAlert_Test.lua (bei /reload)
-- Befehle: /vat

local ADDON_NAME = ...
local VERSION = "0.1.0"
local META = 1217605
local STAR = 1221167
local TICK = 0.25
local LOG_EVERY = 1.0
local MAX_ENTRIES = 8000

local issecret = issecretvalue or function() return false end

local loginNo, lastLog = 0, 0
local lastUsable = {}
local lastAlert = {}
local evCounts = {}

local function Print(msg) print("|cffa335eeVoidAlert_Test|r: " .. msg) end

local function S(v)
  if issecret(v) then return "<SECRET>" end
  if v == nil then return "nil" end
  local t = type(v)
  if t == "number" or t == "string" or t == "boolean" then return v end
  return "<" .. t .. ">"
end

local function add(kind, data)
  local db = VoidAlert_TestLog
  if not db then return end
  data = data or {}
  data.kind = kind
  data.t = math.floor(GetTime() * 100 + 0.5) / 100
  data.login = loginNo
  data.combat = InCombatLockdown() and true or false
  local e = db.entries
  e[#e + 1] = data
  if #e > MAX_ENTRIES then
    local keep = {}
    for i = #e - (MAX_ENTRIES - 1000) + 1, #e do keep[#keep + 1] = e[i] end
    db.entries = keep
  end
end

---------------------------------------------------------------------------
-- Sound-Alarm
---------------------------------------------------------------------------

local ALERTS = {
  [META] = { name = "Leerenmetamorphose", sound = function() return SOUNDKIT and SOUNDKIT.RAID_WARNING end },
  [STAR] = { name = "Kollabierender Stern", sound = function() return SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3 end },
}

local function alert(spellID, via)
  local a = ALERTS[spellID]
  if not a then return end
  local now = GetTime()
  if lastAlert[spellID] and now - lastAlert[spellID] < 2 then return end
  lastAlert[spellID] = now
  local ok, err = pcall(function() PlaySound(a.sound(), "Master") end)
  Print(a.name .. " bereit! (erkannt ueber: " .. via .. ")")
  add("ALERT", { spell = spellID, via = via, soundOk = ok, soundErr = ok and nil or tostring(err) })
end

---------------------------------------------------------------------------
-- Messungen
---------------------------------------------------------------------------

local function probeUsable(out, key, spellID)
  local ok, usable, noMana = pcall(C_Spell.IsSpellUsable, spellID)
  if not ok then out[key .. "_err"] = tostring(usable); return end
  out[key .. "_usable"] = S(usable)
  out[key .. "_noMana"] = S(noMana)
  -- Weg 1: Wechsel auf nutzbar erkennen (nur wenn lesbar)
  if not issecret(usable) then
    if usable == true and lastUsable[spellID] == false then alert(spellID, "IsSpellUsable") end
    lastUsable[spellID] = usable and true or false
  end
end

local function probeCastCount(out, key, spellID)
  if not (C_Spell and C_Spell.GetSpellCastCount) then out[key .. "_count"] = "noAPI"; return end
  local ok, n = pcall(C_Spell.GetSpellCastCount, spellID)
  out[key .. "_count"] = ok and S(n) or ("err:" .. tostring(n))
end

local function probeOverlay(out, key, spellID)
  local api = C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed
  if not api then out[key .. "_overlay"] = "noAPI"; return end
  local ok, v = pcall(api, spellID)
  out[key .. "_overlay"] = ok and S(v) or ("err:" .. tostring(v))
end

local function probeAuras(out)
  local n = 0
  for i = 1, 40 do
    local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
    if not ok then out.auraErr = tostring(aura); break end
    if issecret(aura) then out["aura" .. i] = "<SECRET>"; n = i
    elseif aura == nil then break
    else
    n = i
    if i <= 20 then
      local okId, id = pcall(function() return aura.spellId end)
      local okNm, nm = pcall(function() return aura.name end)
      local okAp, ap = pcall(function() return aura.applications end)
      out["aura" .. i] = tostring(okId and S(id) or "err") .. "|" .. tostring(okNm and S(nm) or "err")
        .. "|stacks=" .. tostring(okAp and S(ap) or "err")
    end
    end
  end
  out.auraCount = n
  -- Metamorphose-Buff direkt abfragen (zwei moegliche IDs laut Wowhead)
  for _, id in ipairs({ 1217605, 1217607 }) do
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
    if not ok then out["buff" .. id] = "err"
    elseif issecret(aura) then out["buff" .. id] = "<SECRET>"
    elseif aura == nil then out["buff" .. id] = "nil"
    else
      local okAp, ap = pcall(function() return aura.applications end)
      out["buff" .. id] = "present|stacks=" .. tostring(okAp and S(ap) or "err")
    end
  end
end

local powerTypes
local function probePowers(out)
  if not powerTypes then
    powerTypes = {}
    if Enum and Enum.PowerType then
      for name, id in pairs(Enum.PowerType) do
        local l = string.lower(name)
        if l:find("soul") or l:find("fury") or l:find("void") or l:find("fragment") then
          powerTypes[#powerTypes + 1] = { name = name, id = id }
        end
      end
    end
  end
  for _, p in ipairs(powerTypes) do
    local ok, v = pcall(UnitPower, "player", p.id)
    local okM, m = pcall(UnitPowerMax, "player", p.id)
    out["pow_" .. p.name] = tostring(ok and S(v) or "err") .. "/" .. tostring(okM and S(m) or "err")
  end
end

local function tick()
  local inCombat = InCombatLockdown()
  local out = {}
  probeUsable(out, "meta", META)
  probeUsable(out, "star", STAR)
  if not inCombat then return end
  local now = GetTime()
  if now - lastLog < LOG_EVERY then return end
  lastLog = now
  probeCastCount(out, "meta", META)
  probeCastCount(out, "star", STAR)
  probeOverlay(out, "meta", META)
  probeOverlay(out, "star", STAR)
  probeAuras(out)
  probePowers(out)
  for e, c in pairs(evCounts) do out["ev_" .. e] = c end
  wipe(evCounts)
  add("tick", out)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= ADDON_NAME then return end
    VoidAlert_TestLog = VoidAlert_TestLog or {}
    local db = VoidAlert_TestLog
    if db.version ~= VERSION then db.entries = {}; db.logins = 0; db.version = VERSION end
    db.entries = db.entries or {}
    db.logins = (db.logins or 0) + 1
    loginNo = db.logins
    local version, build, _, toc = GetBuildInfo()
    local specOk, specID, specName = pcall(function()
      local idx = GetSpecialization()
      return GetSpecializationInfo(idx)
    end)
    add("meta", { addonVersion = VERSION, gameVersion = S(version), build = S(build), toc = S(toc),
      class = select(2, UnitClass("player")), specID = specOk and S(specID) or "err",
      specName = specOk and S(specName) or "err",
      hasCastCount = (C_Spell and C_Spell.GetSpellCastCount) and true or false,
      hasOverlayApi = (C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed) and true or false })
    C_Timer.NewTicker(TICK, function()
      local ok, err = pcall(tick)
      if not ok then add("tickErr", { err = tostring(err) }) end
    end)
    Print("v" .. VERSION .. " geladen. /vat fuer Hilfe")

  elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    local ok, specID, specName = pcall(function() return GetSpecializationInfo(GetSpecialization()) end)
    add("spec", { specID = ok and S(specID) or "err", specName = ok and S(specName) or "err" })

  elseif event == "PLAYER_REGEN_DISABLED" then
    add("combatStart")
  elseif event == "PLAYER_REGEN_ENABLED" then
    add("combatEnd")

  elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
    local spellID = ...
    local secret = issecret(spellID)
    add(event, { spellID = S(spellID), secret = secret })
    -- Weg 2: Aufleuchten
    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" and not secret and ALERTS[spellID] then
      alert(spellID, "Aufleuchten")
    end

  else
    evCounts[event] = (evCounts[event] or 0) + 1
  end
end)

for _, e in ipairs({ "ADDON_LOADED", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_REGEN_DISABLED",
  "PLAYER_REGEN_ENABLED", "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
  "SPELL_UPDATE_USABLE", "UNIT_AURA", "UNIT_POWER_UPDATE" }) do
  if not pcall(f.RegisterEvent, f, e) then Print("Event unbekannt: " .. e) end
end

SLASH_VOIDALERTTEST1 = "/vat"
SlashCmdList.VOIDALERTTEST = function(msg)
  msg = strlower(strtrim(msg or ""))
  if msg == "clear" then wipe(VoidAlert_TestLog.entries); Print("Log geleert")
  elseif msg == "sound" then alert(META, "Test"); C_Timer.After(2.5, function() alert(STAR, "Test") end)
  elseif msg == "snap" then lastLog = 0; local o = {}; probeAuras(o); probePowers(o); add("snap", o); Print("Momentaufnahme geloggt")
  else Print("/vat sound (beide Sounds testen) | snap | clear. Log wird bei /reload gespeichert.") end
end

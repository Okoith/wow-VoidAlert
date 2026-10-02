-- ImmoTest v0.1.0
-- Testaddon fuer VoidAlert: Seelenimmolation (Verschlinger-Daemonenjaeger, Spell-ID 1241937)
--
-- Geprueft wird im Kampf:
--   1. C_Spell.GetSpellCooldown: isActive, isOnGCD, startTime, duration (lesbar oder geheim?)
--   2. C_Spell.GetSpellCharges: currentCharges, maxCharges (mit Talent fuer 2 Aufladungen)
--   3. Leuchten (SPELL_ACTIVATION_OVERLAY_GLOW_SHOW), z. B. nach Reset durch Toetungsschlag
--   4. Eigene Casts (UNIT_SPELLCAST_SUCCEEDED)
-- Erkennung "bereit": isActive wechselt auf false ODER Aufladungen steigen.
-- Dann spielt das Addon im Kampf einen Testsound (Schlachtzugswarnung).
--
-- Log: WTF\Account\<ACCOUNT>\SavedVariables\ImmoTest.lua (bei /reload oder Logout)
-- Befehle: /immotest

local ADDON_NAME = ...
local VERSION = "0.1.0"
local SPELL_ID = 1241937
local MAX_ENTRIES = 8000
local POLL = 0.25

local issecret = issecretvalue or function() return false end
local db
local loginNo = 0
local lastSig
local lastReady      -- true/false/nil (nil = unbekannt)
local lastCharges    -- Zahl oder nil
local ticker

local function Print(msg) print("|cffa335eeImmoTest|r: " .. msg) end

local function S(v)
  if issecret(v) then return "<SECRET>" end
  if v == nil then return "nil" end
  local t = type(v)
  if t == "number" or t == "string" or t == "boolean" then return v end
  return "<" .. t .. ">"
end

local function inCombat()
  local ok, c = pcall(InCombatLockdown)
  return ok and c == true
end

local function add(kind, data)
  if not db then return end
  data = data or {}
  data.kind = kind
  data.t = math.floor(GetTime() * 100 + 0.5) / 100
  data.login = loginNo
  data.combat = inCombat()
  local e = db.entries
  e[#e + 1] = data
  if #e > MAX_ENTRIES then
    local keep = {}
    for i = #e - (MAX_ENTRIES - 1000) + 1, #e do keep[#keep + 1] = e[i] end
    db.entries = keep
  end
end

local function field(tbl, key)
  if tbl == nil or issecret(tbl) or type(tbl) ~= "table" then return nil end
  local ok, v = pcall(function() return tbl[key] end)
  if ok then return v end
  return nil
end

-- Liest den Zustand. Rueckgabe: Log-Tabelle, ready (true/false/nil), charges (Zahl/nil)
local function readState()
  local d = {}
  local okCd, cd = pcall(C_Spell.GetSpellCooldown, SPELL_ID)
  if not okCd then d.cdErr = S(cd); cd = nil end
  d.cdSecret = issecret(cd)
  local isActive, isOnGCD = field(cd, "isActive"), field(cd, "isOnGCD")
  d.isActive = S(isActive)
  d.isOnGCD = S(isOnGCD)
  d.startTime = S(field(cd, "startTime"))
  d.duration = S(field(cd, "duration"))
  d.isEnabled = S(field(cd, "isEnabled"))

  local okCh, ch = pcall(C_Spell.GetSpellCharges, SPELL_ID)
  if not okCh then d.chErr = S(ch); ch = nil end
  d.chType = issecret(ch) and "<SECRET>" or type(ch)
  local cur, max = field(ch, "currentCharges"), field(ch, "maxCharges")
  d.currentCharges = S(cur)
  d.maxCharges = S(max)
  d.chStart = S(field(ch, "cooldownStartTime"))
  d.chDuration = S(field(ch, "cooldownDuration"))

  local okU, usable, noMana = pcall(C_Spell.IsSpellUsable, SPELL_ID)
  if okU then d.usable = S(usable); d.noMana = S(noMana) end

  local ready
  if not issecret(isActive) and type(isActive) == "boolean" then
    ready = (isActive == false)
    if not issecret(isOnGCD) and isOnGCD == true then ready = true end
  end
  local charges
  if not issecret(cur) and type(cur) == "number" then charges = cur end
  d.ready = S(ready)
  return d, ready, charges
end

local function signature(d)
  return table.concat({
    tostring(d.isActive), tostring(d.isOnGCD), tostring(d.currentCharges), tostring(d.maxCharges),
    tostring(d.usable), tostring(d.cdSecret), tostring(d.chType), tostring(d.duration),
  }, "|")
end

local function playTest(reason)
  local okP, willPlay = pcall(PlaySound, SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
  add("sound", { reason = reason, ok = okP, willPlay = S(willPlay) })
  Print("BEREIT (" .. reason .. ")")
end

local function check(source)
  local d, ready, charges = readState()
  local sig = signature(d)
  if sig ~= lastSig then
    d.source = source
    add("state", d)
    lastSig = sig
  end
  -- Uebergaenge
  local trigger
  if ready == true and lastReady == false then trigger = "cdReady" end
  if charges and lastCharges and charges > lastCharges then
    trigger = trigger and (trigger .. "+chargeUp") or "chargeUp"
  end
  if trigger then
    add("trigger", { reason = trigger, source = source, charges = S(charges) })
    if inCombat() then playTest(trigger) end
  end
  if ready ~= nil then lastReady = ready end
  if charges ~= nil then lastCharges = charges end
end

local function startTicker()
  if ticker then return end
  ticker = C_Timer.NewTicker(POLL, function() check("poll") end)
end

local function stopTicker()
  if ticker then ticker:Cancel(); ticker = nil end
end

local frame = CreateFrame("Frame")
for _, ev in ipairs({
  "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_SPECIALIZATION_CHANGED", "TRAIT_CONFIG_UPDATED",
  "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
  "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "SPELL_UPDATE_USABLE",
  "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
  "UNIT_SPELLCAST_SUCCEEDED",
}) do pcall(frame.RegisterEvent, frame, ev) end

frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= ADDON_NAME then return end
    ImmoTestLog = ImmoTestLog or {}
    db = ImmoTestLog
    db.entries = db.entries or {}
    db.logins = (db.logins or 0) + 1
    loginNo = db.logins
    return
  end
  if event == "PLAYER_LOGIN" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED" then
    local d = { event = event, version = VERSION }
    local okC, _, cls = pcall(UnitClass, "player")
    d.class = okC and S(cls) or "err"
    local okS, idx = pcall(GetSpecialization)
    if okS and not issecret(idx) and type(idx) == "number" then
      local okI, specID = pcall(GetSpecializationInfo, idx)
      d.specID = okI and S(specID) or "err"
    end
    d.known = S(select(2, pcall(IsPlayerSpell, SPELL_ID)))
    d.override = S(select(2, pcall(C_Spell.GetOverrideSpell, SPELL_ID)))
    local okN, info = pcall(C_Spell.GetSpellInfo, SPELL_ID)
    d.name = okN and S(field(info, "name")) or "err"
    local st = readState()
    for k, v in pairs(st) do d["s_" .. k] = v end
    add("info", d)
    if event == "PLAYER_LOGIN" then
      Print(("v%s geladen. %s bekannt: %s, /immotest fuer Befehle."):format(VERSION, tostring(d.name), tostring(d.known)))
    end
    return
  end
  if event == "PLAYER_REGEN_DISABLED" then
    add("combatStart")
    lastSig = nil
    check("combatStart")
    startTicker()
    return
  end
  if event == "PLAYER_REGEN_ENABLED" then
    stopTicker()
    check("combatEnd")
    add("combatEnd")
    return
  end
  if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
    local id = ...
    add("glow", { event = event, spellID = S(id), isImmo = (not issecret(id)) and id == SPELL_ID })
    check("glow")
    return
  end
  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, _, spellID = ...
    if unit ~= "player" then return end
    if issecret(spellID) then
      add("cast", { spellID = "<SECRET>" })
    elseif spellID == SPELL_ID then
      add("cast", { spellID = spellID, immo = true })
    end
    check("cast")
    return
  end
  -- SPELL_UPDATE_*
  check(event)
end)

SLASH_IMMOTEST1 = "/immotest"
SlashCmdList.IMMOTEST = function(msg)
  msg = (msg or ""):lower()
  if msg == "clear" then
    wipe(db.entries); Print("Log geleert.")
  elseif msg == "state" then
    local d = readState()
    add("manual", d)
    Print(("isActive=%s isOnGCD=%s Aufladungen=%s/%s bereit=%s"):format(
      tostring(d.isActive), tostring(d.isOnGCD), tostring(d.currentCharges), tostring(d.maxCharges), tostring(d.ready)))
  elseif msg == "sound" then
    playTest("manual")
  else
    Print("/immotest state  Zustand anzeigen und loggen")
    Print("/immotest sound  Testsound")
    Print("/immotest clear  Log leeren")
  end
end

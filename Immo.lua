local ADDON_NAME, ns = ...

-- Dritter Alarm "Seelenimmolation bereit" (SPEC 9). Im Kampf mit ImmoTest geprüft
-- (docs/reference/ImmoTest.lua):
--   Modus 1 (1 Aufladung): isActive/isOnGCD aus C_Spell.GetSpellCooldown, dazu das Leuchten
--     beim Reset durch Spontane Immolation (kommt über Alerts:OnGlowShow).
--   Modus 2 (2 Aufladungen, Gemäßigte Seele): eigener Zähler, weil currentCharges im Kampf
--     geheim ist. Außerhalb des Kampfes mit den echten Werten abgeglichen, im Kampf über
--     eigene Casts und einen Timer geführt und über isActive korrigiert.
-- Gespeichert wird nichts, der Zustand lebt nur in diesem Modul.

local Immo = {}
ns.Immo = Immo

local issecret = issecretvalue or function() return false end

Immo.IMMO_ID = 1241937          -- Seelenimmolation, GetOverrideSpell liefert dieselbe ID (SPEC 9)
Immo.DEFAULT_RECHARGE = 30      -- Sekunden je Aufladung mit Gemäßigte Seele (SPEC 9)

local maxCharges          -- letzter lesbarer Wert von maxCharges
local mode                -- 1 oder 2, nil solange inaktiv
local lastReady           -- Modus 1: letzter Zustand bereit (true/false)
local lastActive          -- Modus 2: letzter lesbarer isActive
local lastStateSig        -- immoState nur bei Änderung loggen
local lastSyncSig         -- immoSync nur bei Änderung loggen
local charges             -- Modus 2: eigener Zähler
local rechargeStart       -- Modus 2: GetTime()-Zeit, seit der die nächste Aufladung lädt
local rechargeDuration = Immo.DEFAULT_RECHARGE
local timer, timerDue

---------------------------------------------------------------------------
-- Lesen (alles in pcall, Secret Values nie vergleichen)
---------------------------------------------------------------------------

local function num(v)
  if issecret(v) or type(v) ~= "number" then return nil end
  return v
end

local function bool(v)
  if issecret(v) or type(v) ~= "boolean" then return nil end
  return v
end

-- Feld einer API-Tabelle; die Tabelle selbst kann fehlen oder geheim sein (wie ImmoTest)
local function field(tbl, key)
  if issecret(tbl) or type(tbl) ~= "table" then return nil end
  local ok, v = pcall(function() return tbl[key] end)
  if ok then return v end
  return nil
end

-- Rohwerte aus C_Spell.GetSpellCharges (können geheim sein)
local function readCharges()
  local ok, info = pcall(C_Spell.GetSpellCharges, Immo.IMMO_ID)
  if not ok then
    ns.Debug:Error("GetSpellCharges", info)
    info = nil
  end
  return {
    max = field(info, "maxCharges"),
    cur = field(info, "currentCharges"),
    start = field(info, "cooldownStartTime"),
    dur = field(info, "cooldownDuration"),
  }
end

-- Rohwerte isActive, isOnGCD aus C_Spell.GetSpellCooldown (können geheim sein)
local function readCooldown()
  local ok, info = pcall(C_Spell.GetSpellCooldown, Immo.IMMO_ID)
  if not ok then
    ns.Debug:Error("GetSpellCooldown", info)
    return nil, nil
  end
  return field(info, "isActive"), field(info, "isOnGCD")
end

local function now()
  return GetTime()
end

---------------------------------------------------------------------------
-- Timer (Modus 2): wartet auf rechargeStart + rechargeDuration
---------------------------------------------------------------------------

function Immo:Schedule()
  local due = (mode == 2 and rechargeStart) and (rechargeStart + rechargeDuration) or nil
  if due == timerDue and (timer or not due) then return end   -- schon so geplant
  if timer then
    pcall(timer.Cancel, timer)
    timer, timerDue = nil, nil
  end
  if not due then return end
  local delay = due - now()
  if delay < 0 then delay = 0 end
  local handle
  local ok, t = pcall(C_Timer.NewTimer, delay, function()
    if handle ~= timer then return end   -- inzwischen ersetzt
    timer, timerDue = nil, nil
    local okRun, err = pcall(Immo.OnTimer, Immo)
    if not okRun then ns.Debug:Error("Immo:OnTimer", err) end
  end)
  if not ok then
    ns.Debug:Error("C_Timer.NewTimer", t)
    return
  end
  handle = t
  timer, timerDue = t, due
end

function Immo:OnTimer()
  if mode ~= 2 or not rechargeStart then return end
  local max = maxCharges or 2
  charges = math.min((charges or 0) + 1, max)
  if charges < max then
    rechargeStart = rechargeStart + rechargeDuration
  else
    rechargeStart = nil
  end
  ns.Debug:Add("immoTimer", {
    charges = charges,
    nextDue = rechargeStart and (rechargeStart + rechargeDuration) or nil,
  })
  self:Schedule()
  ns.Alerts:TryPlay("immo", "chargeTimer")
end

---------------------------------------------------------------------------
-- Modus und Abgleich
---------------------------------------------------------------------------

local function logSync(source, change)
  if not ns.Debug:IsEnabled() then return end
  local sig = table.concat({ tostring(mode), tostring(maxCharges), tostring(charges),
    tostring(rechargeStart), tostring(rechargeDuration) }, "|")
  if sig == lastSyncSig and not change then return end
  lastSyncSig = sig
  ns.Debug:Add("immoSync", {
    mode = mode, max = maxCharges, charges = charges,
    rechargeStart = rechargeStart, rechargeDuration = rechargeDuration,
    source = source, change = change,
  })
end

-- Alles zurücksetzen (inaktiv oder Moduswechsel)
local function reset()
  lastReady, lastActive, lastStateSig = nil, nil, nil
  charges, rechargeStart = nil, nil
  rechargeDuration = Immo.DEFAULT_RECHARGE
end

function Immo:SetMode(newMode, source)
  mode = newMode
  reset()
  -- Modus 2 beginnt voll; der Abgleich außerhalb des Kampfes oder die Korrektur über
  -- isActive ziehen den Zähler nach.
  if mode == 2 then charges = maxCharges end
  self:Schedule()
  logSync(source, "mode")
end

-- Abgleich mit den echten Werten (SPEC 9), nur wenn alle drei lesbar sind, also außerhalb
-- des Kampfes. Spielt keinen Sound. Rückgabe true, wenn abgeglichen wurde.
function Immo:Sync(raw, source)
  local cur, start, dur = num(raw.cur), num(raw.start), num(raw.dur)
  if not (cur and start and dur) then return false end
  charges = cur
  if dur > 0 then rechargeDuration = dur end
  if cur < (maxCharges or 2) and start > 0 then
    rechargeStart = start
  else
    rechargeStart = nil
  end
  self:Schedule()
  logSync(source)
  return true
end

-- isActive/isOnGCD nur bei Änderung loggen
local function logState(rawActive, rawGCD)
  if not ns.Debug:IsEnabled() then return end
  local S = ns.Debug.S
  local a, g = S(rawActive), S(rawGCD)
  local sig = tostring(a) .. "|" .. tostring(g)
  if sig == lastStateSig then return end
  lastStateSig = sig
  ns.Debug:Add("immoState", { isActive = a, isOnGCD = g, mode = mode, charges = charges })
end

-- Modus 1: bereit = isActive false oder (Abklingzeit endet im GCD) isOnGCD true
function Immo:CheckSingle(isActive, isOnGCD)
  if isActive == nil then return end
  local ready = (isActive == false) or (isOnGCD == true)
  local was = lastReady
  lastReady = ready
  if ready and was == false then
    ns.Alerts:TryPlay("immo", "cdReady")
  end
end

-- Modus 2: Zähler über isActive korrigieren (SPEC 9)
function Immo:Correct(isActive, isOnGCD)
  if isActive == nil then return end
  local wasActive = lastActive
  lastActive = isActive
  if charges == nil then return end

  if isActive == true and isOnGCD == false then
    -- echte 0 Aufladungen
    if charges > 0 then
      ns.Debug:Add("immoCorrect", { old = charges, new = 0, reason = "zeroCharges" })
      charges = 0
    end
    return
  end

  if isActive == false and wasActive == true and charges == 0 then
    -- wieder bereit, der Timer kam noch nicht: Alarm hier, Timer für die nächste Aufladung
    charges = 1
    if charges < (maxCharges or 2) then
      rechargeStart = now()
    else
      rechargeStart = nil
    end
    ns.Debug:Add("immoCorrect", { old = 0, new = 1, reason = "ready", rechargeStart = rechargeStart })
    self:Schedule()
    -- Hat der Timer innerhalb der Sperre schon gespielt, verhindert die Sperre den zweiten Alarm
    ns.Alerts:TryPlay("immo", "correct")
  end
end

---------------------------------------------------------------------------
-- Einstieg aus Core.lua
---------------------------------------------------------------------------

-- Bei SPELL_UPDATE_COOLDOWN, SPELL_UPDATE_CHARGES, PLAYER_REGEN_DISABLED/ENABLED,
-- SPELLS_CHANGED, TRAIT_CONFIG_UPDATED, Spezialisierungswechsel und Login.
function Immo:Update(source)
  if not ns.Alerts.active then
    if mode then
      mode = nil
      reset()
      self:Schedule()
      logSync(source, "inactive")
    end
    return
  end

  -- maxCharges bei jedem Update lesen; geheim oder fehlend: letzter Wert, sonst Modus 1
  local raw = readCharges()
  local max = num(raw.max)
  if max and max >= 1 then maxCharges = max end
  local newMode = (maxCharges and maxCharges >= 2) and 2 or 1
  if newMode ~= mode then self:SetMode(newMode, source) end

  if mode == 2 then self:Sync(raw, source) end

  local rawActive, rawGCD = readCooldown()
  logState(rawActive, rawGCD)
  local isActive, isOnGCD = bool(rawActive), bool(rawGCD)
  if mode == 1 then
    self:CheckSingle(isActive, isOnGCD)
  else
    self:Correct(isActive, isOnGCD)
  end
end

-- UNIT_SPELLCAST_SUCCEEDED des Spielers mit Spell-ID 1241937
function Immo:OnCast()
  if not ns.Alerts.active then return end
  if mode ~= 2 then
    ns.Debug:Add("immoCast", { mode = mode })
    return
  end
  -- Außerhalb des Kampfes die echten Werte nehmen statt zu zählen (sonst doppelt gezählt,
  -- wenn SPELL_UPDATE_CHARGES schon vor dem Cast-Ereignis kam)
  local raw = readCharges()
  if self:Sync(raw, "cast") then return end

  local max = maxCharges or 2
  local before = charges or max
  if before >= max then rechargeStart = now() end
  charges = math.max(before - 1, 0)
  -- Fehlt der Startzeitpunkt (z. B. Kampf ohne vorherigen Abgleich), lädt ab jetzt
  if charges < max and not rechargeStart then rechargeStart = now() end
  ns.Debug:Add("immoCast", { before = before, after = charges, rechargeStart = rechargeStart })
  self:Schedule()
end

-- SPELL_ACTIVATION_OVERLAY_GLOW_SHOW mit Spell-ID 1241937: Reset durch Spontane Immolation
-- (Todesstoß). Spontane Immolation und Gemäßigte Seele teilen sich einen Wahlknoten,
-- darum Alarm nur in Modus 1.
function Immo:OnGlow()
  ns.Debug:Add("immoGlow", { mode = mode })
  if (mode or 1) == 1 then
    ns.Alerts:TryPlay("immo", "resetGlow", { spellID = self.IMMO_ID })
  end
end

local ADDON_NAME, ns = ...
local L = ns.L

-- Erkennung (SPEC 2) und Aktivierung nur für den Verschlinger (SPEC 3).
-- Leerenmetamorphose und Kollabierender Stern: einzige Quelle ist
-- SPELL_ACTIVATION_OVERLAY_GLOW_SHOW mit der Spell-ID im Payload.
-- Seelenimmolation hat ein eigenes Modul (Immo.lua, SPEC 9); ihr Leuchten wird dorthin
-- weitergereicht.

local Alerts = {}
ns.Alerts = Alerts

local issecret = issecretvalue or function() return false end

Alerts.VOID_META_ID = 1217605        -- Leerenmetamorphose, im Spiel getestet (SPEC 2)
Alerts.COLLAPSING_STAR_ID = 1221150  -- Kollabierender Stern in der Metamorphose (SPEC 2)
-- Dämonenjäger Verschlinger laut warcraft.wiki.gg (SpecializationID), übernommen aus DotRange.
-- Wird zur Laufzeit mit GetSpecializationInfo verglichen und samt aller Specs der Klasse geloggt.
Alerts.DEVOURER_SPEC_ID = 1480

Alerts.LOCKOUT = 2   -- Sekunden Sperre pro Alarm gegen Doppelauslösung (SPEC 2), auch für "immo"

-- Spell-ID im Ereignis -> Alarm
Alerts.BY_SPELL = {
  [Alerts.VOID_META_ID] = "meta",
  [Alerts.COLLAPSING_STAR_ID] = "star",
}
Alerts.ORDER = { "meta", "star", "immo" }

Alerts.active = false
local lastPlayed = {}   -- Alarm -> GetTime() des letzten Abspielens

---------------------------------------------------------------------------
-- Spezialisierung und bekannte Zauber (alles in pcall, Secret Values nie vergleichen)
---------------------------------------------------------------------------

-- true/false, nil wenn die API fehlt, fehlschlägt oder einen Secret Value liefert
local function safeKnown(func, spellID)
  if not func then return nil end
  local ok, known = pcall(func, spellID)
  if not ok then
    ns.Debug:Error("IsSpellKnown", known)
    return nil
  end
  if issecret(known) then return nil end
  return known
end

function Alerts:IsKnown(spellID)
  return safeKnown(C_SpellBook and C_SpellBook.IsSpellKnown, spellID)
end

-- Aktuelle Spezialisierung: specID, specName (nil, wenn nicht ermittelbar). Aus DotRange.
function Alerts:GetSpec()
  local ok, index = pcall(GetSpecialization)
  if not ok or issecret(index) or type(index) ~= "number" then return nil, nil end
  local okInfo, specID, specName = pcall(GetSpecializationInfo, index)
  if not okInfo or issecret(specID) or type(specID) ~= "number" then return nil, nil end
  if issecret(specName) then specName = nil end
  return specID, specName
end

-- Alle Spezialisierungen der eigenen Klasse (ID und Name), zur Laufzeit ermittelt.
-- Damit lässt sich im Debug-Log prüfen, ob die Verschlinger-ID stimmt. Aus DotRange.
function Alerts:ClassSpecs()
  local out = {}
  if type(self.classID) ~= "number" then return out end
  local okNum, num = pcall(GetNumSpecializationsForClassID, self.classID)
  if not okNum or type(num) ~= "number" then return out end
  for i = 1, num do
    local ok, id, name = pcall(GetSpecializationInfoForClassID, self.classID, i)
    if ok and type(id) == "number" and not issecret(id) and not issecret(name) then
      out["spec" .. i] = tostring(id) .. " " .. tostring(name)
    end
  end
  return out
end

-- Bei PLAYER_LOGIN, dann ist die Klasse sicher bekannt
function Alerts:Init()
  local ok, _, class, classID = pcall(UnitClass, "player")
  if ok then
    self.class = class
    self.classID = classID
  end
end

-- Aktiv, wenn der Charakter Leerenmetamorphose kennt oder die Spec-ID dem Verschlinger
-- entspricht (SPEC 3). Liefern beide Prüfungen kein Ergebnis (API fehlt, Spec noch 0),
-- wird nichts geraten: Ein Dämonenjäger bleibt dann aktiv. Die Spell-IDs der Alarme
-- gibt es ohnehin nur beim Verschlinger.
-- Rückgabe: true, wenn sich Status, Spec-ID oder "bekannt" geändert hat.
function Alerts:Update()
  local specID, specName = self:GetSpec()
  local known = self:IsKnown(self.VOID_META_ID)
  local active, reason
  if self.class ~= "DEMONHUNTER" then
    active, reason = false, "class"
  elseif known == true then
    active, reason = true, "known"
  elseif specID == self.DEVOURER_SPEC_ID then
    active, reason = true, "specID"
  elseif known == nil and specID == nil then
    active, reason = true, "unclear"
  else
    active, reason = false, "notDevourer"
  end
  local changed = active ~= self.active or specID ~= self.specID or known ~= self.known
  self.active, self.reason = active, reason
  self.specID, self.specName, self.known = specID, specName, known
  return changed
end

-- Spec-Eintrag fürs Debug-Log (SPEC 6)
function Alerts:LogSpec(why)
  if not ns.Debug:IsEnabled() then return end
  local out = self:ClassSpecs()
  out.why = why
  out.class = self.class
  out.specID = self.specID
  out.specName = self.specName
  out.devourerSpecID = self.DEVOURER_SPEC_ID
  out.isDevourer = self.specID == self.DEVOURER_SPEC_ID
  out.voidMetaKnown = self.known
  out.voidMetaKnownOrInBook = safeKnown(C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook, self.VOID_META_ID)
  out.collapsingStarKnown = self:IsKnown(self.COLLAPSING_STAR_ID)
  out.active = self.active
  out.reason = self.reason
  ns.Debug:Add("spec", out)
end

---------------------------------------------------------------------------
-- Alarme
---------------------------------------------------------------------------

function Alerts:SpellName(spellID)
  local ok, name = pcall(C_Spell.GetSpellName, spellID)
  if ok and type(name) == "string" and not issecret(name) then return name end
  return nil
end

-- Sound für einen Alarm abspielen. Ist der gespeicherte Schlüssel nicht mehr auflösbar
-- (z. B. LSM-Sound eines entfernten Addons), wird der Standard verwendet.
function Alerts:Play(alert, why)
  local p = ns.db.profile
  local key = p.alerts[alert].sound
  local Sounds = ns.Sounds
  local fallback
  if not Sounds:Resolve(key) then
    fallback = key
    key = Sounds.DEFAULTS[alert]
  end
  local result = Sounds:Play(key, p.channel)
  result.alert = alert
  result.why = why
  result.fallbackFrom = fallback
  ns.Debug:Add("alarm", result)
  return result
end

-- Gemeinsame Bedingungen für alle Auslöser: aktiv (Verschlinger), Alarm an, "Nur im Kampf"
-- und die Sperre pro Alarm. info: zusätzliche Felder fürs Debug-Log.
-- Rückgabe true, wenn der Sound abgespielt wurde.
function Alerts:TryPlay(alert, why, info)
  local skip
  if not self.active then
    skip = "inactive"
  elseif not ns.db.profile.alerts[alert].enabled then
    skip = "disabled"
  elseif ns.db.profile.combatOnly and not ns.inCombat then
    skip = "notInCombat"
  else
    local now = GetTime()
    if lastPlayed[alert] and now - lastPlayed[alert] < self.LOCKOUT then
      skip = "lockout"
    else
      lastPlayed[alert] = now
    end
  end
  if skip then
    local out = { alert = alert, why = why, skip = skip }
    if info then
      for k, v in pairs(info) do out[k] = v end
    end
    ns.Debug:Add("alarmSkipped", out)
    return false
  end
  self:Play(alert, why)
  return true
end

-- GLOW_SHOW: Sound für Leerenmetamorphose und Kollabierender Stern (SPEC 2),
-- Seelenimmolation (Reset durch Spontane Immolation) geht an ns.Immo (SPEC 9)
function Alerts:OnGlowShow(spellID)
  if issecret(spellID) then
    ns.Debug:Add("glowShow", { spellID = spellID })   -- wird als "<SECRET>" gespeichert
    return
  end
  local isImmo = spellID == ns.Immo.IMMO_ID
  local alert = self.BY_SPELL[spellID]
  if ns.Debug:IsEnabled() then
    ns.Debug:Add("glowShow", { spellID = spellID, name = self:SpellName(spellID), alert = isImmo and "immo" or alert })
  end
  if isImmo then
    ns.Immo:OnGlow()
    return
  end
  if not alert then return end
  self:TryPlay(alert, "glow", { spellID = spellID })
end

function Alerts:OnGlowHide(spellID)
  if not ns.Debug:IsEnabled() then return end
  if issecret(spellID) then
    ns.Debug:Add("glowHide", { spellID = spellID })
    return
  end
  local alert = (spellID == ns.Immo.IMMO_ID) and "immo" or self.BY_SPELL[spellID]
  ns.Debug:Add("glowHide", { spellID = spellID, name = self:SpellName(spellID), alert = alert })
end

-- /voidalert test: spielt einen oder alle Alarme, unabhängig von an/aus, Kampf und Sperre.
-- Nacheinander, damit sie sich nicht überlagern.
local TEST_GAP = 2

function Alerts:Test(which)
  local list = which and { which } or self.ORDER
  for i, alert in ipairs(list) do
    C_Timer.After((i - 1) * TEST_GAP, function()
      local ok, err = pcall(function()
        local result = self:Play(alert, "test")
        if ns.db.profile.chatMessages then
          ns.Print(L["TEST_PLAYING"]:format(L["ALERT_" .. alert], ns.Sounds:Label(result.sound)))
        end
      end)
      if not ok then ns.Debug:Error("Test", err) end
    end)
  end
end

-- ============================================================
--  Forever Cast Bars — module Ressources
--  Sur les barres d'action de Blizzard : quand un sort coûte plus
--  que la mana (rage, énergie…) disponible, le haut de son icône
--  s'assombrit et le bas se remplit, aux couleurs du thème FCB du
--  sort, à mesure que la ressource revient. Quand le sort devient
--  lançable : flash, puis icône normale. Pendant une recharge plus
--  longue que la recharge globale (pierre de foyer, sac de couchage,
--  sorts), l'icône se remplit de la même façon, au thème de l'objet
--  ou du sort, et flashe quand elle est prête. Exige ForeverCastBars.
--
--  Le remplissage est une StatusBar invisible (le moteur calcule la
--  hauteur, même si la valeur est secrète) ; les textures visibles
--  sont sur la couche ARTWORK du bouton, sous le temps de recharge,
--  les raccourcis et la bordure. Rien n'est créé en combat.
-- ============================================================

if not (FCB and FCB.Themes) then return end

local M = "Interface\\AddOns\\ForeverCastBars_Ressources\\textures\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local BARS = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }
local FILL_ALPHA, DARK_ALPHA = 0.7, 0.55

local R = { overlays = {}, squares = {} }
FCB.Ressources = R

local min, wipe = math.min, wipe or function(t) for k in pairs(t) do t[k] = nil end end
local function Secret(v) return issecretvalue and issecretvalue(v) or false end

local GCD = 1.6                -- en dessous : recharge globale, déjà visible sur le bouton

-- sort d'un emplacement d'action (sort direct, sort d'une macro, sort d'utilisation d'un objet)
local function ActionSpell(slot)
    if not slot then return nil end
    local kind, id = GetActionInfo(slot)
    if kind == "spell" then return id end
    if kind == "macro" and GetMacroSpell then return GetMacroSpell(id) end
    if kind == "item" and C_Item and C_Item.GetItemSpell then return select(2, C_Item.GetItemSpell(id)) end
end

-- recharge de l'emplacement : début, durée ; nil si aucune, trop courte, ou valeur secrète
local function Cooldown(slot)
    local start, dur
    if GetActionCooldown then start, dur = GetActionCooldown(slot)
    elseif C_ActionBar and C_ActionBar.GetActionCooldown then
        local c = C_ActionBar.GetActionCooldown(slot); if type(c) == "table" then start, dur = c.startTime, c.duration end
    end
    if Secret(start) or Secret(dur) or type(start) ~= "number" or type(dur) ~= "number" then return nil, Secret(start) or Secret(dur) end
    if start > 0 and dur > GCD then return start, dur end
end

-- coût minimal du sort dans une ressource, et son type de puissance
local function Cost(spellID)
    local costs = C_Spell and C_Spell.GetSpellPowerCost and C_Spell.GetSpellPowerCost(spellID)
    if type(costs) ~= "table" or Secret(costs) then return nil end
    for _, c in ipairs(costs) do
        local need = c.minCost or c.cost
        local aura = c.requiredAuraID
        if not Secret(need) and not Secret(c.type) and type(need) == "number" and need > 0
            and not (type(aura) == "number" and aura ~= 0 and not c.hasRequiredAura) then
            return need, c.type
        end
    end
end

-- texture carrée et couleur du thème FCB du sort (look du sort d'abord : remplissages des packs)
local looks = {}
local function Look(spellID)
    if looks[spellID] then return looks[spellID][1], looks[spellID][2] end
    local Th = FCB.Themes
    local key = Th:Detect(spellID) or "physical"
    local info = C_Spell.GetSpellInfo(spellID); local name = info and info.name
    local L = Th.Look and Th:Look(key, name)
    local fill = (L and L.fill) or Th:Get(key).fill
    local sq = M .. "Sq_" .. (fill:match("([^\\]+)$") or "Fill_physical")
    local col = Th:Get(key).color or { 1, 1, 1 }
    R.squares[sq] = true
    looks[spellID] = { sq, col }
    return sq, col
end

local function Build(button)
    local icon = button.icon or button.Icon
    if not icon then return end
    local o = {}
    o.bar = CreateFrame("StatusBar", nil, button)                    -- invisible : sert de règle pour la hauteur
    o.bar:SetAllPoints(icon); o.bar:SetOrientation("VERTICAL"); o.bar:SetStatusBarTexture(WHITE); o.bar:SetAlpha(0)
    local top = o.bar:GetStatusBarTexture()
    o.fill = button:CreateTexture(nil, "ARTWORK", nil, 6)
    o.fill:SetPoint("TOPLEFT", top, "TOPLEFT"); o.fill:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT"); o.fill:SetAlpha(FILL_ALPHA)
    o.dark = button:CreateTexture(nil, "ARTWORK", nil, 5)
    o.dark:SetTexture(WHITE); o.dark:SetVertexColor(0, 0, 0); o.dark:SetAlpha(DARK_ALPHA)
    o.dark:SetPoint("TOPLEFT", icon, "TOPLEFT"); o.dark:SetPoint("BOTTOMRIGHT", top, "TOPRIGHT")
    o.edge = button:CreateTexture(nil, "ARTWORK", nil, 7)
    o.edge:SetTexture(WHITE); o.edge:SetHeight(1.5)
    o.edge:SetPoint("LEFT", top, "TOPLEFT"); o.edge:SetPoint("RIGHT", top, "TOPRIGHT")
    o.flash = button:CreateTexture(nil, "ARTWORK", nil, 7)
    o.flash:SetTexture(WHITE); o.flash:SetBlendMode("ADD"); o.flash:SetAllPoints(icon); o.flash:SetAlpha(0)
    local g = o.flash:CreateAnimationGroup()
    local a1 = g:CreateAnimation("Alpha"); a1:SetFromAlpha(0); a1:SetToAlpha(0.8); a1:SetDuration(0.12); a1:SetOrder(1)
    local a2 = g:CreateAnimation("Alpha"); a2:SetFromAlpha(0.8); a2:SetToAlpha(0); a2:SetDuration(0.35); a2:SetOrder(2)
    o.flashGroup = g
    if button.IconMask then for _, t in ipairs({ o.fill, o.dark, o.edge, o.flash }) do t:AddMaskTexture(button.IconMask) end end
    for _, t in ipairs({ o.fill, o.dark, o.edge }) do t:Hide() end
    R.overlays[button] = o
end

local function Show(o, on) for _, t in ipairs({ o.fill, o.dark, o.edge }) do if on then t:Show() else t:Hide() end end end

local function Paint(o, spell, maxV, value)
    local sq, col = Look(spell)
    o.col = col
    o.fill:SetTexture(sq); o.edge:SetVertexColor(min(1, col[1] + .4), min(1, col[2] + .4), min(1, col[3] + .4))
    o.bar:SetMinMaxValues(-maxV * 0.001, maxV)                       -- jamais exactement 0 : la règle garde une hauteur
    o.bar:SetValue(value)
    Show(o, true)
end

function R:Update(button, o)
    local slot = button.action
    local spell = ActionSpell(slot)
    o.cd = nil
    if spell then
        local start, dur = Cooldown(slot)                            -- 1) recharge en cours
        if start then
            o.cd = { start, dur }
            Paint(o, spell, dur, GetTime() - start)
            o.waiting, o.slot = slot, slot
            return
        end
        local need, ptype = Cost(spell)                              -- 2) pas assez de ressource
        if need then
            local _, short = (C_ActionBar and C_ActionBar.IsUsableAction or IsUsableAction)(slot)
            if Secret(short) then o.waiting = nil; Show(o, false); return end   -- valeur secrète : rien n'est comparé
            if short then
                Paint(o, spell, need, UnitPower("player", ptype))
                o.waiting, o.slot = slot, slot
                return
            end
        end
    end
    if o.waiting and o.waiting == slot then                           -- prêt (même emplacement) : flash
        o.flash:SetVertexColor(unpack(o.col or { 1, 1, 1 })); o.flashGroup:Play()
    end
    o.waiting = nil
    Show(o, false)
end

-- avance des recharges affichées (appelé 4 fois par seconde tant qu'une recharge est visible)
function R:Tick()
    local any, now = false, GetTime()
    for button, o in pairs(self.overlays) do
        if o.cd then
            if now >= o.cd[1] + o.cd[2] then self:Update(button, o) else o.bar:SetValue(now - o.cd[1]) end
            any = any or o.cd ~= nil
        end
    end
    return any
end

local ticker
function R:UpdateAll()
    local any = false
    for button, o in pairs(self.overlays) do self:Update(button, o); any = any or o.cd ~= nil end
    if ticker then if any then ticker:Show() else ticker:Hide() end end
end

function R:Init()
    if InCombatLockdown and InCombatLockdown() then return end
    for _, bar in ipairs(BARS) do
        for i = 1, 12 do
            local b = _G[bar .. i]
            if b and not self.overlays[b] then Build(b) end
        end
    end
end

ticker = CreateFrame("Frame")
ticker:Hide()
local acc = 0
ticker:SetScript("OnUpdate", function(self, dt)
    acc = acc + dt
    if acc < 0.25 then return end
    acc = 0
    if not R:Tick() then self:Hide() end
end)

-- événements : regroupés, une seule mise à jour à l'image suivante
local f = CreateFrame("Frame")
local pending = false
local function Schedule()
    if pending then return end
    pending = true
    C_Timer.After(0, function() pending = false; R:UpdateAll() end)
end
f:SetScript("OnEvent", function(_, ev)
    if ev == "PLAYER_LOGIN" then R:Init() end
    if ev == "PLAYER_REGEN_ENABLED" or ev == "SPELLS_CHANGED" or ev == "UPDATE_SHAPESHIFT_FORM" then wipe(looks) end
    if ev == "PLAYER_REGEN_ENABLED" then R:Init() end
    Schedule()
end)
for _, ev in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ACTIONBAR_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
    "ACTIONBAR_UPDATE_USABLE", "SPELL_UPDATE_USABLE", "UPDATE_SHAPESHIFT_FORM", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED" }) do
    pcall(f.RegisterEvent, f, ev)
end
pcall(f.RegisterUnitEvent, f, "UNIT_POWER_FREQUENT", "player")

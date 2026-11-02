local _,P=...
-- A hardware-click secure spell button opens the real profession session.
-- Hiding Blizzard's frame can close that session, so never hide or alter it.
function P:CreateProfessionButton(parent)
    local b=CreateFrame("Button","ProfPadenOpenProfession",parent,"SecureActionButtonTemplate,UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT",628,-130);b:SetSize(112,24);b:SetText("Profession")
    b:RegisterForClicks("AnyUp","AnyDown");b:SetAttribute("useOnKeyDown",false)
    self.professionButton=b;self:RefreshProfessionButton()
end
function P:RefreshProfessionButton()
    if not self.professionButton or InCombatLockdown() then return end
    local b=self.professionButton;local spell
    local profession=self.selected and self.selected.journeyPrepare and self.selected.profession or self.selectedProf
    for _,prof in ipairs(self.professions) do if prof[1]==profession then spell=profession=="Mining" and 2656 or prof[2];break end end
    local name=C_Spell and C_Spell.GetSpellName and spell and C_Spell.GetSpellName(spell) or GetSpellInfo and spell and GetSpellInfo(spell)
    b:SetAttribute("type",name and "spell" or nil);b:SetAttribute("spell",name)
    b:SetEnabled(self.skills[profession]~=nil and name~=nil)
    b:SetText("Open profession")
end

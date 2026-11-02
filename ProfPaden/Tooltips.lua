local _,P=...
function P:ShowListingTooltip(owner,r)
    if not r or not GameTooltip then return end
    local recipe=r.link and tonumber(r.link:match("^profpaden:recipe:(%d+)$"))
    local producer=r.link and tonumber(r.link:match("^profpaden:make:(%d+)$"))
    local material=r.link and tonumber(r.link:match("^profpaden:material:(%d+)$"))
    if recipe or producer then r={spell=recipe or producer} elseif material then r={item=material} end
    if r.link and (r.link:match("^profpaden:uses:") or r.link:match("^profpaden:methods:") or r.link:match("^profpaden:sources:") or r.link:match("^profpaden:sourcescope:")) then return end
    GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
    local ok
    local place=r.link and r.link:match("^profpaden:place:([%w%-]+):")
    local location=place and self.SourceLocations and self.SourceLocations[place]
    if location then
        GameTooltip:SetText(location.name);local p=location.point
        GameTooltip:AddLine(p.zone..string.format(" %.1f, %.1f",p.x*100,p.y*100),1,.82,.4,true)
        GameTooltip:AddLine("Click for directions. Clears when you buy the recipe.",.8,.76,.66,true)
        GameTooltip:Show();return
    end
    local npcID=r.link and tonumber(r.link:match("^profpaden:npc:(%d+)"))
    if npcID and self.NPCSources[npcID] then
        local npc=self.NPCSources[npcID];GameTooltip:SetText(npc.name)
        GameTooltip:AddLine(npc.title or "",1,.82,.4,true)
        local target=self:NearestNPC({npcID},nil,r.link:match(":drop$")~=nil)
        if target and target.point.entrance then GameTooltip:AddLine("Directions lead to the dungeon entrance, not the NPC's room.",1,.82,.4,true) end
        if target then
            GameTooltip:AddLine("Click for a map waypoint and directions.",.8,.76,.66,true)
        else
            if #(npc.locations or {})>0 then GameTooltip:AddLine(table.concat(npc.locations,", "),.8,.76,.66,true) end
            GameTooltip:AddLine("No recorded waypoint for this source.",.8,.76,.66,true)
        end
        GameTooltip:Show();return
    elseif r.link and (r.link:match("^item:%d+") or r.link:match("^spell:%d+")) then
        ok=pcall(GameTooltip.SetHyperlink,GameTooltip,r.link)
    elseif r.item then
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(r.item) end
        ok=pcall(GameTooltip.SetItemByID,GameTooltip,r.item)
    elseif r.spell then ok=pcall(GameTooltip.SetSpellByID,GameTooltip,r.spell) end
    if not ok then GameTooltip:SetText(r.name or r.title or "Recipe details") end
    if r.planAccess then GameTooltip:AddLine(r.planAccess,1,.82,.4,true) end
    if r.mats and #r.mats>0 then GameTooltip:AddLine("Select to inspect materials. Hover a material name for its tooltip.",.8,.76,.66,true) end
    GameTooltip:Show()
end

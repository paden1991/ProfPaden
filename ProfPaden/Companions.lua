local _,P=...
P.companions={}
local loaded=C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
P.companions.fishingExternal=loaded and loaded("BetterFishing") or false
P.companions.nodesExternal=loaded and loaded("NodeSight") or false
-- Vendor files have guards and isolated SavedVariables. Standalone installations win.

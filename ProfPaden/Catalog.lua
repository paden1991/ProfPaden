local _,P=...
function P:CatalogRows()
    local prof=self.selectedProf;local entries,seen,itemOnly={},{},{}
    self.listTotal=0
    local function add(base)
        local key=base.spell and "s"..base.spell or base.item and "i"..base.item or base.name
        if seen[key] or base.item and itemOnly[base.item] then return end;seen[key]=true
        if base.item and not base.spell then itemOnly[base.item]=true end
        local r={};for k,v in pairs(base) do r[k]=v end
        r.key="catalog:"..key;r.mats=r.mats or {}
        local live=self:Resolve(r)
        local cached
        for _,v in pairs(self.char.recipes[prof] or {}) do if self.SameRecipe(r,v) then cached=v;break end end
        local observed=self.char.catalog and self.char.catalog[prof] and self.char.catalog[prof][key]
        r.known=live~=nil or cached~=nil or observed and observed.learned
        r.ownership=r.known and "Known" or observed and "Unlearned" or "Not yet checked"
        local actual=live or cached
        if actual then
            for _,k in ipairs({"name","mats","complete","difficulty","output","outputMax","available","api","cooldown","item","spell","enchant","blocked","icon"}) do if actual[k]~=nil then r[k]=actual[k] end end
            r.live=live~=nil;r.cached=not live
        end
        if observed and observed.learned==false and observed.sourceText and observed.sourceText~="" then r.source=observed.sourceText end
        if not r.source or r.source=="" then r.source="Acquisition source not supplied by the client or guide." end
        self.listTotal=self.listTotal+1
        local filter=self.catalogFilter or "all"
        if filter=="favorites" and not self:IsFavorite(r) then return end
        if filter=="known" and not r.known or filter=="unlearned" and (r.known or not observed) then return end
        if filter=="trainer" then
            local trainer=self.char.trainers and self.char.trainers[prof] and self.char.trainers[prof][key]
            if not (trainer or r.sourceKinds and r.sourceKinds.trainer or r.sourceKind=="trainer" or r.source:lower():find("trainer",1,true)) then return end
        end
        if filter=="drop" and not (r.sourceKinds and r.sourceKinds.drop or r.sourceKind=="drop" or r.source:lower():find("drop")) then return end
        if filter=="vendor" and not (r.sourceKinds and r.sourceKinds.vendor or r.sourceKind=="vendor" or r.source:lower():find("vendor")) then return end
        local search=(self.catalogSearch or ""):lower()
        if search~="" and not (r.name.." "..r.source.." "..tostring(r.item or "").." "..tostring(r.spell or "")):lower():find(search,1,true) then return end
        if not self:MatchesFacets(r,false) then return end
        -- The list only displays bag readiness; cost sourcing belongs to the selected detail.
        r.ready=self:Available(r)
        entries[#entries+1]=r
    end
    for _,r in ipairs(self.Catalog[prof] or {}) do add(r) end
    for _,r in ipairs(self.Recipes[prof] or {}) do add(r) end
    for _,r in pairs(self.char.catalog and self.char.catalog[prof] or {}) do add(r) end
    for _,r in pairs(self.char.recipes[prof] or {}) do add(r) end
    table.sort(entries,function(a,b)if (a.learn or 0)~=(b.learn or 0) then return (a.learn or 0)<(b.learn or 0) end;return a.name<b.name end)
    return entries
end

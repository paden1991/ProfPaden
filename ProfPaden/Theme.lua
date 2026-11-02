local _,P=...
-- Presentation only. The planner, source data, action handlers and saved tab IDs
-- remain owned by their existing modules.
local T={};P.Theme=T
local ART="Interface\\AddOns\\ProfPaden\\Assets\\Theme\\"
local WHITE="Interface\\Buttons\\WHITE8X8"
local body="Fonts\\ARIALN.TTF"
local heading="Fonts\\FRIZQT__.TTF"
if CreateFont then
    T.buttonFont=CreateFont("ProfPadenArtisanButtonFont");T.buttonFont:SetFont(body,20,"");T.buttonFont:SetTextColor(.953,.910,.816)
    T.disabledFont=CreateFont("ProfPadenArtisanDisabledFont");T.disabledFont:SetFont(body,20,"");T.disabledFont:SetTextColor(.64,.62,.57)
end
function T.Font(region,size,serif)
    if not region then return end
    region:SetFont(serif and heading or body,size,"")
    region:SetTextColor(.953,.910,.816,1)
    region:SetShadowColor(0,0,0,.8);region:SetShadowOffset(0,-1)
end
function T.Place(region,x,y,w,h)
    region:ClearAllPoints();region:SetPoint("TOPLEFT",x,-y)
    if w then region:SetWidth(w) end;if h then region:SetHeight(h) end
end
function T.Panel(frame,raised)
    frame:SetBackdrop({bgFile=WHITE,edgeFile=WHITE,edgeSize=1})
    frame:SetBackdropColor(raised and .145 or .098,raised and .157 or .106,raised and .169 or .110,1)
    frame:SetBackdropBorderColor(.39,.33,.24,1)
end
function T.DetailOrder(p,rows)
    local r=p.selected
    if not r or not r.mats or r.money or r.quest or r.journeyPrepare or r.acquisitionOnly then return rows end
    local first,last
    for i,row in ipairs(rows) do
        if row.heading and #row.cells==1 then
            if first then last=i-1;break end
            if tostring(row.cells[1]):find("^MATERIALS") then first=i end
        end
    end
    if not first or first<=2 then return rows end
    last=last or #rows
    -- Reading order only: retain every original row and value exactly once.
    -- Identity and type stay first, then materials, then the complete economics
    -- and source sections in the same scrolling detail pane.
    local ordered={rows[1],rows[2]}
    for i=first,last do ordered[#ordered+1]=rows[i] end
    for i=3,first-1 do ordered[#ordered+1]=rows[i] end
    for i=last+1,#rows do ordered[#ordered+1]=rows[i] end
    return ordered
end
function T.Chrome(frame)
    T.Panel(frame)
    -- Nine independent regions: fixed corners and narrow edges never stretch the
    -- rivets or leather header vertically when a companion has a different size.
    local function slice(l,r,t,b)
        local x=frame:CreateTexture(nil,"BORDER");x:SetTexture(ART.."ArtisanFrame.tga");x:SetTexCoord(l,r,t,b);return x
    end
    local tl=slice(0,.06,0,.112);tl:SetPoint("TOPLEFT");tl:SetSize(60,76)
    local tr=slice(.94,1,0,.112);tr:SetPoint("TOPRIGHT");tr:SetSize(60,76)
    local top=slice(.06,.94,0,.112);top:SetPoint("TOPLEFT",tl,"TOPRIGHT");top:SetPoint("BOTTOMRIGHT",tr,"BOTTOMLEFT")
    local bl=slice(0,.06,.936,1);bl:SetPoint("BOTTOMLEFT");bl:SetSize(60,44)
    local br=slice(.94,1,.936,1);br:SetPoint("BOTTOMRIGHT");br:SetSize(60,44)
    local bottom=slice(.06,.94,.936,1);bottom:SetPoint("TOPLEFT",bl,"TOPRIGHT");bottom:SetPoint("BOTTOMRIGHT",br,"BOTTOMLEFT")
    local left=slice(0,.016,.112,.936);left:SetPoint("TOPLEFT",tl,"BOTTOMLEFT");left:SetPoint("BOTTOMLEFT",bl,"TOPLEFT");left:SetWidth(16)
    local right=slice(.984,1,.112,.936);right:SetPoint("TOPRIGHT",tr,"BOTTOMRIGHT");right:SetPoint("BOTTOMRIGHT",br,"TOPRIGHT");right:SetWidth(16)
end
function T.Button(b,primary)
    if not b then return end
    if b.artisanSkin~=true then
        b.artisanSkin=true
        -- Preserve the native Button and its click/secure behavior; replace only
        -- the stock red artwork. The child plate does not receive input.
        b:SetNormalTexture(WHITE);b:SetPushedTexture(WHITE);b:SetHighlightTexture(WHITE)
        local plate=CreateFrame("Frame",nil,b,"BackdropTemplate");plate:SetAllPoints();T.Panel(plate)
        plate:SetFrameLevel(math.max(0,(b:GetFrameLevel() or 1)-1));b.artisanPlate=plate
        local leather=plate:CreateTexture(nil,"BACKGROUND");leather:SetPoint("TOPLEFT",1,-1);leather:SetPoint("BOTTOMRIGHT",-1,1)
        leather:SetTexture(ART.."ArtisanFrame.tga");leather:SetTexCoord(.12,.88,.016,.10);leather:SetAlpha(.24)
        local n=b:GetNormalTexture();if n then n:SetVertexColor(0,0,0,0) end
        local p=b:GetPushedTexture();if p then p:SetVertexColor(.8,.6,.25,.2) end
        local h=b:GetHighlightTexture();if h then h:SetVertexColor(.95,.75,.35,.13) end
        -- UIPanelButtonTemplate also owns three split textures, independent of
        -- GetNormalTexture. Keep them transparent through enable/disable changes.
        for _,r in ipairs({b:GetRegions()}) do
            if r:GetObjectType()=="Texture" and r~=n and r~=p and r~=h and r~=b.dropdownArrow then r:SetAlpha(0) end
        end
        if T.buttonFont then b:SetNormalFontObject(T.buttonFont);b:SetHighlightFontObject(T.buttonFont);b:SetDisabledFontObject(T.disabledFont) end
        b:HookScript("OnDisable",function(s)if s.artisanPrimary then s.artisanPlate:SetBackdropColor(.13,.13,.13,1);s.artisanPlate:SetBackdropBorderColor(.4,.38,.34,1) end end)
        b:HookScript("OnEnable",function(s)if s.artisanPrimary then s.artisanPlate:SetBackdropColor(.36,.25,.085,1);s.artisanPlate:SetBackdropBorderColor(.85,.67,.32,1) end end)
    end
    b.artisanPrimary=primary
    local plate=b.artisanPlate
    plate:SetBackdropColor(primary and .30 or .145,primary and .215 or .157,primary and .085 or .169,1)
    plate:SetBackdropBorderColor(primary and .85 or .48,primary and .67 or .43,primary and .32 or .34,1)
    T.Font(b:GetFontString(),20)
end
function T.Edit(e)
    T.Font(e,18);e:SetTextInsets(9,9,0,0)
    if e.artisanSkin~=true then
        e.artisanSkin=true
        for _,key in ipairs({"Left","Middle","Right"}) do local r=e[key];if (type(r)=="table" or type(r)=="userdata") and r.Hide then r:Hide() end end
        local plate=CreateFrame("Frame",nil,e,"BackdropTemplate");plate:SetAllPoints();T.Panel(plate);plate:SetFrameLevel(math.max(0,(e:GetFrameLevel() or 1)-1))
    end
end
function T.Initialize(p)
    if p.artisanReady and p.artisanWindow==p.window then return true end
    p.artisanReady=false
    if InCombatLockdown() then return false end
    p.artisanReady=true;p.artisanWindow=p.window
    local f=p.window;f:SetSize(1440,980)
    f:SetScale(math.min(1,(UIParent:GetWidth()-24)/1440,(UIParent:GetHeight()-24)/980))
    T.Chrome(f)
    T.Place(p.brand,96,20,280,42);T.Font(p.brand,32,true);p.brand:SetText("PROFPADEN");p.brand:SetTextColor(.85,.69,.37)
    T.Place(p.tagline,394,29,650,32);T.Font(p.tagline,22);p.tagline:SetText("Artisan's Field Guide")
    T.Place(p.brandIcon,23,9,62,62);p.brandIcon:SetTexture(ART.."ArtisanEmblem.tga")
    T.Place(p.sidebar,16,84,238,832);T.Panel(p.sidebar)
    T.Place(p.sidebarTitle,16,18,210,28);T.Font(p.sidebarTitle,22,true);p.sidebarTitle:SetText("PROFESSIONS")
    for i,pr in ipairs(p.professions) do
        local b=p.profButtons[pr[1]];T.Place(b,8,61+(i-1)*56,222,54)
        T.Place(b.icon,8,8,36,36);T.Place(b.title,54,7,166,24);T.Font(b.title,20)
        T.Place(b.rank,54,31,165,20);T.Font(b.rank,16)
        local plate=CreateFrame("Frame",nil,b,"BackdropTemplate");plate:SetAllPoints();T.Panel(plate);plate:SetFrameLevel(math.max(0,(b:GetFrameLevel() or 1)-1));b.artisanPlate=plate
    end
    p.professionIcon=f:CreateTexture(nil,"ARTWORK");T.Place(p.professionIcon,278,98,48,48)
    T.Place(p.heading,340,92,600,42);T.Font(p.heading,32,true)
    T.Place(p.rankText,340,135,590,38);T.Font(p.rankText,18)
    p.skillTrack=f:CreateTexture(nil,"ARTWORK");p.skillTrack:SetPoint("TOPLEFT",340,-174);p.skillTrack:SetSize(590,4);p.skillTrack:SetColorTexture(.25,.23,.18,1)
    p.skillFill=f:CreateTexture(nil,"OVERLAY");p.skillFill:SetPoint("TOPLEFT",340,-174);p.skillFill:SetHeight(4);p.skillFill:SetColorTexture(.85,.69,.37,1)
    T.Place(p.professionButton,956,96,202,36);T.Button(p.professionButton)
    T.Place(p.scanButton,1170,96,244,36);T.Button(p.scanButton)
    T.Place(p.autoArrows,30,864,208,36);T.Button(p.autoArrows)
    T.Place(p.listPanel,270,226,450,690);T.Panel(p.listPanel)
    T.Place(p.detail,732,226,692,690);T.Panel(p.detail)
    p.readableDetailWidth=636
    T.Place(p.modeButton,16,16,240,34);T.Button(p.modeButton)
    T.Place(p.search,16,60,418,34);T.Edit(p.search)
    p.searchHint=p.search:CreateFontString(nil,"OVERLAY");p.searchHint:SetPoint("LEFT",10,0);T.Font(p.searchHint,18);p.searchHint:SetTextColor(.78,.75,.68)
    T.Place(p.planGoalLabel,274,25,57,24);T.Font(p.planGoalLabel,18)
    T.Place(p.planGoal,334,16,100,34);T.Edit(p.planGoal)
    for i,k in ipairs({"type","quality","new"}) do local b=p.facetButtons[k];T.Place(b,16+(i-1)*142,104,134,32);T.Button(b) end
    for i,k in ipairs({"knowledge","skill","source","bags"}) do local b=p.materialFilterButtons[k];T.Place(b,16+((i-1)%2)*214,104+math.floor((i-1)/2)*38,204,32);T.Button(b) end
    T.Place(p.prev,16,642,100,34);T.Button(p.prev)
    T.Place(p.page,128,651,188,25);T.Font(p.page,18)
    T.Place(p.next,330,642,104,34);T.Button(p.next)
    T.Button(p.resetFilters)
    p.detailIcon=p.detail:CreateTexture(nil,"ARTWORK");T.Place(p.detailIcon,22,16,58,58)
    T.Place(p.detailTitle,96,18,574,58);T.Font(p.detailTitle,27,true);p.detailTitle:SetWordWrap(true)
    for i,b in ipairs({p.pinRecipe,p.excludeRecipe,p.resetChoices}) do T.Place(b,22+(i-1)*188,84,i==3 and 272 or 178,32);T.Button(b) end
    p.detailScroll:ClearAllPoints();p.detailScroll:SetPoint("TOPLEFT",22,-132);p.detailScroll:SetPoint("BOTTOMRIGHT",-34,112)
    p.detailChild:SetWidth(638);p.detailBody:SetWidth(636);T.Font(p.detailBody,20);p.detailBody:SetSpacing(6)
    T.Place(p.qtyLabel,22,594,100,28);T.Font(p.qtyLabel,18)
    T.Place(p.qty,100,584,80,38);T.Edit(p.qty)
    T.Place(p.craft,196,584,250,38);T.Button(p.craft,true)
    T.Place(p.priceButton,462,584,208,38);T.Button(p.priceButton)
    T.Place(p.routeAction,22,584,424,38);T.Button(p.routeAction,true)
    T.Place(p.source,22,642,470,32);T.Edit(p.source)
    T.Place(p.sourceNext,508,642,162,32);T.Button(p.sourceNext)
    T.Place(p.status,28,935,1380,36);T.Font(p.status,16);p.status:SetSpacing(2)
    f:HookScript("OnDragStart",function()if T.dock then T.dock.moved=true end end)
    return true
end
function T.Refresh(p)
    if not p.window or not T.Initialize(p) then return end
    local index=0
    for _,name in ipairs({"Recipes","Catalog","Gather","Quests"}) do
        local b=p.tabs[name]
        if b:IsShown() then T.Place(b,276+index*148,184,140,32);index=index+1 end
        T.Button(b,name==p.tab)
        if name=="Recipes" then b:SetText("Leveling") end
    end
    T.Place(p.campButton,276+index*148,184,140,32);T.Button(p.campButton)
    T.Place(p.shoppingButton,276+(index+1)*148,184,140,32);T.Button(p.shoppingButton)
    p.heading:SetText(p.selectedProf)
    local skill=p.skills[p.selectedProf];p.skillFill:SetWidth(math.max(1,590*math.min(1,skill and skill.rank/math.max(1,skill.cap) or 0)));p.skillFill:SetShown(skill~=nil)
    p.searchHint:SetText(p.tab=="Gather" and "Search materials or item ID" or p.tab=="Quests" and "Search quests, starter or zone" or "Search recipes, source or ID")
    p.searchHint:SetShown(p.search:GetText()=="")
    local selected=p.selected
    p.detailIcon:SetTexture(selected and (selected.icon or (selected.item and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(selected.item))) or "Interface\\Icons\\INV_Misc_Book_09")
    local mapView=selected and (selected.gatherItem or selected.gatherGuide or selected.gatherBand)
    p.detailScroll:ClearAllPoints();p.detailScroll:SetPoint("TOPLEFT",22,mapView and -88 or -132);p.detailScroll:SetPoint("BOTTOMRIGHT",-34,mapView and 64 or 112)
    for name,b in pairs(p.profButtons) do
        local selected=name==p.selectedProf
        if selected then p.professionIcon:SetTexture(b.icon:GetTexture()) end
        b.artisanPlate:SetBackdropColor(selected and .28 or .105,selected and .22 or .112,selected and .12 or .12,1)
        b.artisanPlate:SetBackdropBorderColor(selected and .85 or .25,selected and .67 or .24,selected and .32 or .21,1)
        b.title:SetTextColor(.953,.910,.816,1)
    end
    local materials=p:MaterialFiltersActive()
    local expanded=materials or p.tab=="Catalog" or p.tab=="Quests"
    local top=materials and 210 or expanded and 172 or 106
    local step=materials and 61 or expanded and 65 or 75
    T.Place(p.listHint,16,materials and 185 or expanded and 145 or 64,280,24);T.Font(p.listHint,16)
    T.Place(p.resetFilters,324,materials and 178 or expanded and 140 or 60,110,28)
    for i,b in ipairs(p.rows) do
        T.Place(b,10,top+(i-1)*step,430,step-(materials and 3 or 5))
        T.Panel(b)
        local selected=b.entry and b.entry==p.selected
        b:SetBackdropColor(selected and .26 or .125,selected and .21 or .137,selected and .11 or .145,1)
        b:SetBackdropBorderColor(selected and .85 or .29,selected and .67 or .29,selected and .32 or .26,1)
        local grouped=b.materialGroup:IsShown()
        T.Place(b.icon,8,grouped and 20 or 10,36,36)
        T.Place(b.title,54,grouped and 20 or 9,366,24);T.Font(b.title,grouped and 18 or 20)
        T.Place(b.sub,54,grouped and 40 or 35,366,grouped and 16 or 22);T.Font(b.sub,grouped and 16 or 18)
        T.Place(b.materialGroup,8,2,414,18);T.Font(b.materialGroup,15)
        T.Place(b.materialRule,8,19,414,1)
    end
end

function T.RestoreDock()
    local d=T.dock
    if not d or InCombatLockdown() then return end
    if not d.moved then
        P.window:SetScale(d.scale);P.window:ClearAllPoints()
        if #d.points==0 then P.window:SetPoint("CENTER") else for _,pt in ipairs(d.points) do P.window:SetPoint(unpack(pt)) end end
    end
    T.dock=nil
end
function T.DockRoute(f)
    if not P.window or not P.window:IsShown() or InCombatLockdown() then return end
    if not T.dock then
        local points={};for i=1,(P.window:GetNumPoints() or 0) do points[i]={P.window:GetPoint(i)} end
        T.dock={points=points,scale=P.window:GetScale() or 1,frame=f}
    end
    -- A gutter between two independent movable windows; no addon is reparented
    -- or embedded. Restore the guide position when the companion closes.
    local scale=math.min(1,(UIParent:GetWidth()-36)/1946,(UIParent:GetHeight()-24)/980)
    P.window:SetScale(scale);P.window:ClearAllPoints();P.window:SetPoint("LEFT",UIParent,"LEFT",12/scale,0)
    f:SetScale(scale);f:ClearAllPoints();f:SetPoint("TOPLEFT",P.window,"TOPRIGHT",16,0)
end

function T.RouteInitialize(f)
    if f.artisanReady==true then return end
    f.artisanReady=true;f:SetSize(490,920)
    f:SetScale(math.min(1,(UIParent:GetHeight()-24)/920))
    T.Chrome(f);T.Place(f.title,24,24,412,36);T.Font(f.title,25,true);f.title:SetText("ProfPaden Routes")
    T.Place(f.summary,24,96,442,190);T.Font(f.summary,18);f.summary:SetSpacing(6);f.summary:SetJustifyV("TOP")
    T.Place(f.travel,24,302,248,38);T.Place(f.trip,282,302,184,38)
    T.Place(f.radius,24,350,442,38);T.Place(f.radiusNote,24,397,442,24);T.Font(f.radiusNote,17)
    T.Place(f.terrain,24,432,442,42);T.Place(f.scope,24,484,442,38)
    T.Place(f.status,24,542,442,44);T.Font(f.status,20)
    T.Place(f.toggle,24,604,214,42);T.Place(f.useSelected,250,604,216,42)
    T.Place(f.routeButtons[1],24,656,214,36);T.Place(f.train,250,656,216,36)
    T.Place(f.routeButtons[2],24,702,140,36);T.Place(f.routeButtons[3],174,702,140,36);T.Place(f.routeButtons[4],324,702,142,36)
    for _,b in ipairs({f.travel,f.trip,f.radius,f.terrain,f.scope,f.useSelected,f.train}) do T.Button(b) end
    for _,b in ipairs(f.routeButtons) do T.Button(b) end
    T.Button(f.toggle,true)
    T.Place(f.note,24,760,442,104);T.Font(f.note,17);f.note:SetSpacing(4);f.note:SetJustifyV("TOP")
    T.DockRoute(f)
    f:HookScript("OnHide",T.RestoreDock)
end

-- Presentation refreshes may run in combat; only the one-time layout touches
-- the protected profession button. Defer that layout until combat ends.
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:RegisterEvent("UI_SCALE_CHANGED")
events:SetScript("OnEvent",function()
    if not P.window or InCombatLockdown() then return end
    local ready=P.artisanReady;T.Refresh(P)
    if T.dock then
        if T.dock.frame:IsShown() then if not T.dock.moved then T.DockRoute(T.dock.frame) end else T.RestoreDock() end
    else P.window:SetScale(math.min(1,(UIParent:GetWidth()-24)/1440,(UIParent:GetHeight()-24)/980)) end
    if not ready then P:Refresh() end
end)

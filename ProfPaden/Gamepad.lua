local _,P=...
local G={roots={},serial=0,commands={},last={},hooked=setmetatable({},{__mode='k'}),enters=setmetatable({},{__mode='k'})};P.gamepad=G
local function visible(f)return f and f.IsVisible and f:IsVisible() end
local function combat()return InCombatLockdown and InCombatLockdown() end
local function invoke(f,event,...)
    local fn=f and f:GetScript(event);if fn then return fn(f,...) end
end
local function clean(s)return (tostring(s or ''):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')) end
local function belongs(f,root)
    if not root then return false end
    while f do if f==root then return true end;f=f:GetParent() end
    return false
end
function G:HideFocus()
    if self.ring then self.ring:Hide();self.ring:ClearAllPoints() end
end
function G:Enabled()
    if not P.char or P.char.gamepadEnabled==false then return false end
    return P.char.gamepadEnabled==true or C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled()
end
function G:Attach(f,kind,passive)
    if not f or self.roots[f] then return end
    self.roots[f]={kind=kind,order=0}
    f:HookScript('OnShow',function()
        if not passive then G.serial=G.serial+1;G.roots[f].order=G.serial;G.suspended=false end
        G:Sync()
    end)
    f:HookScript('OnHide',function()
        if passive then G.roots[f].order=0 end
        -- OnHide can run inside an existing Sync (including close-button callbacks).
        -- Cleanup must not be skipped by Sync's re-entrancy guard.
        if belongs(G.root,f) then G:Release() end
        G:Sync()
    end)
    if visible(f) and not passive then self.serial=self.serial+1;self.roots[f].order=self.serial end
end
function G:Discover()
    if ProfPadenRoutes and not self.walkHook and hooksecurefunc then
        self.walkHook=true;hooksecurefunc(ProfPadenRoutes,'ShowPanel',function()G:Sync()end)
    end
    self:Attach(P.window,'guide');self:Attach(P.shoppingWindow,'shopping')
    self:Attach(P.priceWindow,'price');self:Attach(P.campRoot,'camp',true)
    self:Attach(ProfPadenRoutes and ProfPadenRoutes.panel,'walking')
end
function G:Root()
    if visible(self.keyboard) then return self.keyboard,'keyboard' end
    if visible(P.dropdown) then return P.dropdown.menu,'dropdown' end
    if visible(P.priceWindow) then return P.priceWindow,'price' end
    local root,order,kind=nil,0
    for f,info in pairs(self.roots) do if visible(f) and info.order>order then root,order,kind=f,info.order,info.kind end end
    return root,kind
end
function G:Usable(f)
    if not visible(f) or f==P.source then return false end
    local kind=f:GetObjectType()
    if kind~='Button' and kind~='CheckButton' and kind~='EditBox' then return false end
    if f.IsEnabled and not f:IsEnabled() then return false end
    if kind~='EditBox' and not f:GetScript('OnClick') and not f:GetAttribute('type') and f.campAction~='craft' then return false end
    -- All existing protected profession/camp actions have real named buttons.
    if f.IsProtected and f:IsProtected() and not f:GetName() then return false end
    local l,b,w,h=f:GetRect();if not (l and b and w and h and w>0 and h>0) then return false end
    local parent=f:GetParent()
    while parent do
        if parent:GetObjectType()=='ScrollFrame' then
            local x,y,pw,ph=parent:GetRect()
            if x and (l+w<=x or l>=x+pw or b+h<=y or b>=y+ph) then return false end
        end
        parent=parent:GetParent()
    end
    return true
end
function G:Collect(root)
    local out={}
    local function visit(f,depth)
        if depth>12 or not visible(f) then return end
        if self:Usable(f) then
            local l,b,w,h=f:GetRect();local scale=f:GetEffectiveScale()
            out[#out+1]={frame=f,x=(l+w/2)*scale,y=(b+h/2)*scale}
            if not self.hooked[f] then
                self.hooked[f]=true
                self.enters[f]=f:GetScript('OnEnter')
                f:HookScript('OnHide',function()
                    if G.focus==f then G:HideFocus();G.focus=nil;G:Sync() end
                end)
                f:HookScript('PostClick',function()G:Sync()end)
                f:HookScript('OnEnter',function()
                    local parent=f
                    while parent and parent~=G.root do parent=parent:GetParent() end
                    if parent and G.active and G:Usable(f) then G:SetFocus(f) end
                end)
            end
        end
        for _,child in ipairs({f:GetChildren()}) do visit(child,depth+1) end
    end
    visit(root,0)
    table.sort(out,function(a,b)if a.y~=b.y then return a.y>b.y end;return a.x<b.x end)
    return out
end
function G:Label(f)
    if f==P.search then return 'Search' elseif f==P.qty then return 'Craft quantity' elseif f==P.planGoal then return 'Target skill / batch' end
    if P.shoppingWindow and f==P.shoppingWindow.levels then return 'Shopping target skill' end
    if P.priceWindow and f==P.priceWindow.item then return 'Price: item ID' end
    if P.priceWindow and f==P.priceWindow.value then return 'Price: copper per item' end
    if f==P.campToggle then return 'Camp supplies' end
    if f.campAction=='craft' then return 'Make a Basic Campfire Kit' end
    if f.campAction=='open' then return 'Open Cooking to make a campfire' end
    if f.spellID then return 'Basic Campfire' end
    if f.itemID then return P:ItemName(f.itemID) end
    local value=f and f.GetText and f:GetText()
    if (not value or value=='') and f and f.title then value=f.title:GetText() end
    if (not value or value=='') and f and f.label then value=f.label:GetText() end
    return clean(value~='' and value or f and f:GetName() or 'Select')
end
function G:SetFocus(f)
    if combat() or not self.owner then return end
    if not self.active or not visible(self.root) then self:Release();return end
    if f and (not belongs(f,self.root) or not self:Usable(f)) then return end
    if self.focus~=f then
        if self.focus then invoke(self.focus,'OnLeave') end
        self.focus=f
        if f then
            -- Use the original tooltip handler without recursing through our mouse hook.
            if self.enters[f] then self.enters[f](f)
            elseif f.entry and P.ShowListingTooltip then P:ShowListingTooltip(f,f.entry) end
        end
    end
    -- Tooltip/leave callbacks may hide a panel or transfer focus synchronously.
    if not self.active or not visible(self.root) then self:Release();return end
    if self.focus~=f then return end
    if f and (not belongs(f,self.root) or not self:Usable(f)) then self:HideFocus();return end
    if not f then self:HideFocus();SetOverrideBindingClick(self.owner,true,'PAD1','ProfPadenPadConfirm','LeftButton');return end
    self.last[self.root]=f
    self.ring:ClearAllPoints();self.ring:SetPoint('TOPLEFT',f,'TOPLEFT',-3,3);self.ring:SetPoint('BOTTOMRIGHT',f,'BOTTOMRIGHT',3,-3);self.ring:Show()
    self.hint.label:SetText(self.kind=='keyboard' and 'D-pad: move  |  A / Cross: select  |  B / Circle: cancel\nChoose Done to apply your entry.\n'..self:Label(f) or 'D-pad: move  |  A / Cross: select  |  B / Circle: back\nLB / RB: page  |  LT / RT: details  |  X / Square: links  |  Y / Triangle: panels\n'..self:Label(f))
    -- A named secure target receives the real hardware binding directly.
    -- Never invoke a secure action from a synthesized Lua click.
    local target=f:GetObjectType()~='EditBox' and f:GetName() or nil
    SetOverrideBindingClick(self.owner,true,'PAD1',target or 'ProfPadenPadConfirm','LeftButton')
end
function G:Release()
    -- Remove the UIParent-owned decoration before any other cleanup callbacks.
    self:HideFocus();if self.hint then self.hint:Hide() end
    if self.owner and not combat() then ClearOverrideBindings(self.owner) end
    if self.focus and GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner()==self.focus then GameTooltip:Hide() end
    self.active=false;self.bound=false;self.focus=nil;self.root=nil
end
function G:Sync()
    if self.syncing then return end;self.syncing=true
    self:Discover()
    if combat() or not self:Enabled() or self.suspended then
        if visible(self.keyboard) then self.keyboard:Hide() end
        self:Release();self.syncing=false;return
    end
    if visible(self.keyboard) and self.edit and not visible(self.edit.target) then self.keyboard:Hide() end
    if visible(GameMenuFrame) or visible(SettingsPanel) or visible(StaticPopup1) then self:Release();self.syncing=false;return end
    local root,kind=self:Root()
    -- Chat entry and other focused text fields keep the controller keyboard.
    local edit=GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if edit and not (self.keyboard and visible(self.keyboard)) then self:Release();self.syncing=false;return end
    if not root or not self:Create() then self:Release();self.syncing=false;return end
    local changed=self.root~=root;self.root=root;self.kind=kind;self.active=true
    local list=self:Collect(root);self.list=list
    local focus=changed and self.last[root] or self.focus;local valid=false
    for _,entry in ipairs(list) do if entry.frame==focus then valid=true end end
    if not valid then focus=list[1] and list[1].frame end
    if not self.bound then
        for key,name in pairs(self.commands) do SetOverrideBindingClick(self.owner,true,key,name,'LeftButton') end
        self.bound=true
    end
    self.hint:Show();self:SetFocus(focus);self.syncing=false
end
function G:Move(dx,dy)
    self:Sync();if not self.active or not self.focus then return end
    local current
    for _,p in ipairs(self.list) do if p.frame==self.focus then current=p end end
    if not current then return end
    local best,score
    for _,p in ipairs(self.list) do if p~=current then
        local x,y=p.x-current.x,p.y-current.y;local along=x*dx+y*dy;local across=math.abs(x*dy-y*dx)
        local cost=along+across*3+(across>along and across*4 or 0)
        if along>3 and (not score or cost<score) then best,score=p,cost end
    end end
    if best then self:SetFocus(best.frame) end
end
function G:Confirm()
    local previous=self.focus;self:Sync()
    if not self.active or self.focus~=previous or not self:Usable(previous) then return end
    if previous:GetObjectType()=='EditBox' then self:Keyboard(previous)
    elseif not (previous.IsProtected and previous:IsProtected()) then previous:Click('LeftButton') end
    self:Sync()
end
function G:Back()
    if combat() then return end
    if visible(self.keyboard) then self.keyboard:Hide();self:Sync();return end
    if visible(P.dropdown) then
        local first=P.dropdown.rows and P.dropdown.rows[1]
        if first and first.label and first.label:GetText()=='< Back' then first:Click('LeftButton') else P:CloseDropdown() end
    elseif self.root==P.campRoot then P.campManualOpen=false;P:RefreshCamp()
    elseif self.root then self.root:Hide() end
    self:Sync()
end
function G:Page(delta)
    if not self.active or combat() or self.kind=='dropdown' or self.kind=='keyboard' then return end
    local b=self.kind=='shopping' and (delta<0 and P.shoppingWindow.prev or P.shoppingWindow.next) or self.kind=='guide' and (delta<0 and P.prev or P.next)
    if b and self:Usable(b) then b:Click('LeftButton');self:Sync() end
end
function G:Scroll(delta)
    if not self.active or combat() then return end
    local f=self.kind=='guide' and P.detailScroll or self.kind=='shopping' and P.shoppingWindow.scroll
    if f then f:SetVerticalScroll(math.max(0,math.min(f:GetVerticalScrollRange(),f:GetVerticalScroll()+delta*110))) end
end
function G:Links()
    if not self.active or combat() then return end
    local body=self.kind=='guide' and P.detailBody or self.kind=='shopping' and P.shoppingWindow.body
    local child=self.kind=='guide' and P.detailChild or self.kind=='shopping' and P.shoppingWindow.child
    if not body or not child or not self.focus then return end
    local options,seen={},{}
    for link,label in (body:GetText() or ''):gmatch('|H(.-)|h(.-)|h') do
        if not seen[link] then options[#options+1]={label=clean(label),value=link};seen[link]=true end
    end
    if #options==0 then P:Print('This detail has no item or navigation links.');return end
    -- Bound menu height and retain all links through Next / Back pages.
    local owner=self.focus
    local function page(offset)
        local list={}
        if offset>1 then list[#list+1]={label='< Previous links',value='page:'..(offset-10)} end
        for i=offset,math.min(#options,offset+9) do list[#list+1]=options[i] end
        if offset+10<=#options then list[#list+1]={label='More links >',value='page:'..(offset+10)} end
        P:ToggleDropdown(owner,list,nil,function(value)
            local n=tonumber(value:match('^page:(%d+)$'))
            if n then page(n) else invoke(child,'OnHyperlinkClick',value,nil,'LeftButton');if value:match('^item:') then P:ShowListingTooltip(owner,{link=value}) end end
        end,true)
    end
    page(1);self:Sync()
end
function G:Panels()
    if not self.focus or combat() or self.kind=='keyboard' then return end
    local options={{label='Profession guide',value='guide'},{label='Shopping',value='shopping'},{label='Camp wheel',value='camp'}}
    if ProfPadenRoutes then options[#options+1]={label='Walking routes',value='walking'} end
    options[#options+1]={label='Release controller focus',value='release'}
    P:ToggleDropdown(self.focus,options,nil,function(value)
        if value=='release' then G.suspended=true;G:Release();return end
        if value=='guide' then if not visible(P.window) then P:Toggle() end
        elseif value=='shopping' then if not visible(P.shoppingWindow) then P:ToggleShopping() end
        elseif value=='camp' then P.campManualOpen=true;P:RefreshCamp()
        elseif value=='walking' then ProfPadenRoutes:ShowPanel() end
        G:Discover()
        local root=value=='guide' and P.window or value=='shopping' and P.shoppingWindow or value=='camp' and P.campRoot or ProfPadenRoutes and ProfPadenRoutes.panel
        if root and G.roots[root] then G.serial=G.serial+1;G.roots[root].order=G.serial end
        G:Sync()
    end);self:Sync()
end
function G:Create()
    if self.owner then return true end
    if not SetOverrideBindingClick or not ClearOverrideBindings or not RegisterStateDriver or combat() then return false end
    local owner=CreateFrame('Frame','ProfPadenPadBindings',UIParent,'SecureHandlerStateTemplate');self.owner=owner
    owner:SetAttribute('_onstate-combat',[[if newstate == 'combat' then self:ClearBindings() end]])
    RegisterStateDriver(owner,'combat','[combat] combat; safe')
    local bindings={PADDDOWN=function()G:Move(0,-1)end,PADDUP=function()G:Move(0,1)end,
        PADDLEFT=function()G:Move(-1,0)end,PADDRIGHT=function()G:Move(1,0)end,
        PAD1=function()G:Confirm()end,PAD2=function()G:Back()end,PAD3=function()G:Links()end,PAD4=function()G:Panels()end,
        PADLSHOULDER=function()G:Page(-1)end,PADRSHOULDER=function()G:Page(1)end,
        PADLTRIGGER=function()G:Scroll(-1)end,PADRTRIGGER=function()G:Scroll(1)end}
    for key,action in pairs(bindings) do
        local name=key=='PAD1' and 'ProfPadenPadConfirm' or 'ProfPadenPad'..key
        local b=CreateFrame('Button',name,UIParent);b:RegisterForClicks('LeftButtonUp')
        b:SetScript('OnClick',function()if not combat() then action() end end);self.commands[key]=name
    end
    local ring=CreateFrame('Frame',nil,UIParent,'BackdropTemplate');self.ring=ring
    ring:EnableMouse(false);ring:SetFrameStrata('TOOLTIP')
    ring:SetBackdrop({edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12});ring:SetBackdropBorderColor(1,.83,.15,1)
    -- A final visibility guard for parent hides outside normal addon callbacks.
    -- Runs only while the small decoration is shown; no control discovery here.
    ring:SetScript('OnUpdate',function()
        if not G.active or not visible(G.root) or not visible(G.focus) then G:HideFocus() end
    end)
    local hint=CreateFrame('Frame',nil,UIParent,'BackdropTemplate');self.hint=hint
    hint:SetSize(560,64);hint:SetPoint('BOTTOM',UIParent,'BOTTOM',0,40);hint:SetFrameStrata('TOOLTIP');hint:EnableMouse(false)
    hint:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=10});hint:SetBackdropColor(.04,.035,.02,.95)
    hint.label=hint:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');hint.label:SetPoint('CENTER');hint.label:SetSize(536,50)
    ring:Hide();hint:Hide();return true
end
function P:GamepadFocus()
    if combat() then self:Print('Controller navigation resumes after combat.');return end
    self.char.gamepadEnabled=true;G.suspended=false
    if not visible(self.window) and not visible(self.shoppingWindow) then self:Toggle() end
    G:Sync()
end
BINDING_NAME_PROFPADEN_GAMEPAD='Focus ProfPaden with controller'
local events=CreateFrame('Frame');G.events=events
for _,event in ipairs({'ADDON_LOADED','PLAYER_LOGIN','PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED','GAME_PAD_ACTIVE_CHANGED','GAME_PAD_DISCONNECTED','CVAR_UPDATE'}) do pcall(events.RegisterEvent,events,event) end
events:SetScript('OnEvent',function(_,event)
    G:Sync()
end)
-- Visibility/state polling is cheap; full focus discovery runs only on input
-- or an actual addon UI refresh. No global control, cursor or CVar changes.
local elapsed=0
events:SetScript('OnUpdate',function(_,dt)
    elapsed=elapsed+dt;if elapsed<.25 then return end;elapsed=0
    local root=G:Root();local edit=GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    local blocked=visible(GameMenuFrame) or visible(SettingsPanel) or visible(StaticPopup1)
    if G.active and (root~=G.root or not G:Usable(G.focus) or edit or not G:Enabled() or blocked) or
        not G.active and root and not G.suspended and not blocked and not edit and not combat() and G:Enabled() then G:Sync() end
end)
if hooksecurefunc then
    for _,name in ipairs({'CreateUI','Refresh','RefreshShopping','CreateShoppingUI','PriceEditor','ToggleDropdown','CloseDropdown'}) do
        if P[name] then hooksecurefunc(P,name,function()G:Sync()end) end
    end
    hooksecurefunc(P,'ToggleCamp',function()
        G:Discover();if visible(P.campRoot) and G.roots[P.campRoot] then G.serial=G.serial+1;G.roots[P.campRoot].order=G.serial end;G:Sync()
    end)
end

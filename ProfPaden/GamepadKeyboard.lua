local _,P=...
local G=P.gamepad
function G:Keyboard(target)
    if InCombatLockdown() then return end
    if not self.keyboard then
        local f=CreateFrame('Frame','ProfPadenPadKeyboard',UIParent,'BackdropTemplate');self.keyboard=f
        f:SetSize(590,330);f:SetPoint('CENTER');f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetClampedToScreen(true);f:EnableMouse(true)
        f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',edgeSize=24})
        f:SetBackdropColor(.07,.06,.04,1)
        f.title=f:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');f.title:SetPoint('TOPLEFT',22,-20)
        f.value=f:CreateFontString(nil,'OVERLAY','GameFontHighlight');f.value:SetPoint('TOPLEFT',22,-52);f.value:SetWidth(544);f.value:SetHeight(40);f.value:SetJustifyH('LEFT')
        f.keys={}
        local function key(label,x,y,w,action)
            local b=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');b:SetSize(w,30);b:SetPoint('TOPLEFT',x,y);b:SetText(label);b:SetScript('OnClick',action);return b
        end
        local function append(value)
            if not G.edit or #G.edit.buffer+#value>G.edit.limit then return end
            G.edit.buffer=G.edit.buffer..value;f.value:SetText(G.edit.buffer..'_')
        end
        for row,letters in ipairs({'1234567890','qwertyuiop','asdfghjkl','zxcvbnm-.'}) do
            for i=1,#letters do
                local value=letters:sub(i,i);local b=key(value,22+(i-1)*54,-98-(row-1)*36,48,function()append(value)end)
                b.padDigit=row==1;f.keys[#f.keys+1]=b
            end
        end
        f.space=key('Space',22,-248,102,function()append(' ')end)
        key('Erase',130,-248,102,function()
            if not G.edit then return end
            local s=G.edit.buffer;local first=#s
            while first>0 and s:byte(first)>=128 and s:byte(first)<=191 do first=first-1 end
            G.edit.buffer=s:sub(1,first-1);f.value:SetText(G.edit.buffer..'_')
        end)
        key('Clear',238,-248,102,function()if G.edit then G.edit.buffer='';f.value:SetText('_') end end)
        key('Done',346,-248,102,function()G:CommitEdit()end)
        key('Cancel',454,-248,112,function()f:Hide()end)
        local note=f:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');note:SetPoint('TOPLEFT',22,-291);note:SetWidth(544);note:SetText('D-pad: move   A / Cross: select   B / Circle: cancel. Done applies the value.')
        f:HookScript('OnHide',function()G.edit=nil;G:Sync()end);tinsert(UISpecialFrames,'ProfPadenPadKeyboard')
    end
    local numeric=target.IsNumeric and target:IsNumeric()
    local limit=target.GetMaxLetters and target:GetMaxLetters() or 0
    self.edit={target=target,buffer=target:GetText() or '',limit=limit>0 and limit or 128}
    target:ClearFocus()
    for _,b in ipairs(self.keyboard.keys) do b:SetShown(not numeric or b.padDigit) end
    self.keyboard.space:SetShown(not numeric)
    self.keyboard.title:SetText(numeric and 'Enter a number' or 'Enter search text')
    self.keyboard.value:SetText(self.edit.buffer..'_');self.last[self.keyboard]=nil;self.keyboard:Show();self:Sync()
end
function G:CommitEdit()
    if InCombatLockdown() or not self.edit then return end
    local target,value=self.edit.target,self.edit.buffer
    if not target:IsVisible() then self.keyboard:Hide();return end
    self.keyboard:Hide();target:SetText(value)
    local enter=target:GetScript('OnEnterPressed');local changed=target:GetScript('OnTextChanged')
    if enter then enter(target) elseif changed then changed(target,true) end
    target:ClearFocus();self:Sync()
    if self:Usable(target) and self.root then self:SetFocus(target) end
end

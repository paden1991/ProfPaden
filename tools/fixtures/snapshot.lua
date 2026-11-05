-- UI-only reference harness. No actions are executed in the WoW client.
local methods={}
local mt={__index=function(_,key)return methods[key] or function()end end}
function CreateFrame(kind,name,parent,template)
 local f=setmetatable({kind=kind,name=name,parent=parent,template=template,scripts={},shown=true,width=0,height=0,points={}},mt)
 if name then _G[name]=f end;return f
end
function methods:SetScript(k,v)self.scripts[k]=v end
function methods:HookScript(k,v)local old=self.scripts[k];self.scripts[k]=function(...)if old then old(...)end;v(...)end end
function methods:RegisterEvent()end
function methods:SetPoint(...)self.points[#self.points+1]={...}end
function methods:ClearAllPoints()self.points={}end
function methods:SetSize(w,h)self.width=w;self.height=h end
function methods:SetWidth(w)self.width=w end
function methods:SetHeight(h)self.height=h end
function methods:GetWidth()return self.width end
function methods:GetHeight()return self.height end
function methods:CreateFontString()return CreateFrame('Font',nil,self)end
function methods:CreateTexture()return CreateFrame('Texture',nil,self)end
function methods:CreateLine()return CreateFrame('Line',nil,self)end
function methods:SetTexture(s)self.texture=s end
function methods:SetNormalTexture(s)self.texture=s;self.normal=self:CreateTexture();self.normal:SetTexture(s) end
function methods:GetNormalTexture()return self.normal end
function methods:SetBackdrop(b)self.backdrop=b end
function methods:SetBackdropColor(...)self.backdropColor={...}end
function methods:SetTexCoord(...)self.texcoords={...}end
function methods:SetHyperlinksEnabled(v)self.hyperlinks=v end
function methods:SetText(s)self.text=tostring(s or '')end
function methods:GetText()return self.text or '' end
function methods:SetNumber(n)self.text=tostring(n)end
function methods:SetShown(s)self.shown=s and true or false end
function methods:Show()self.shown=true end
function methods:Hide()self.shown=false end
function methods:IsShown()return self.shown end
function methods:SetEnabled(s)self.enabled=s and true or false end
function methods:SetScrollChild(c)self.child=c end
function methods:SetVerticalScroll(n)self.scroll=n end
function methods:SetAttribute(k,v)self.attrs=rawget(self,'attrs') or {};self.attrs[k]=v end
function methods:GetStringHeight()
 local text=(self.text or ''):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','');local lines=0
 for line in (text..'\n'):gmatch('(.-)\n')do lines=lines+math.max(1,math.ceil(#line/50))end
 return lines*18
end
UIParent=CreateFrame('Frame','UIParent');UIParent:SetSize(1440,900)
UISpecialFrames={};SlashCmdList={};tinsert=table.insert
C_Timer={After=function()end}
function GetRealmName()return 'Reference Realm'end
function UnitFactionGroup()return 'Alliance'end
function UnitLevel()return 30 end
function time()return 1792108800 end
function InCombatLockdown()return false end
function GetNumSkillLines()return 1 end
function GetSkillLineInfo()return 'Alchemy',false,false,60,0,0,150 end
function GetBuildInfo()return '1.60.1','70291','',16001 end
C_AddOns={IsAddOnLoaded=function()return false end}
C_Spell={GetSpellName=function(id)return ({[2259]='Alchemy',[2656]='Smelting'})[id]end}
C_QuestLog={IsQuestFlaggedCompleted=function()return false end,IsOnQuest=function()return false end}
Bag={[765]=12,[2447]=8,[3371]=100,[279981]=3,[279978]=1,[279956]=2,[279970]=1,[279968]=4,[279967]=1}
C_Item={GetItemCount=function(id)return Bag[id] or 0 end,GetItemInfo=function()end}
function SetupReference()
 P=ProfPaden;P:Init();P:CreateUI();P.window:Show()
 P.market.prices[765]={value=100,time=time()};P.market.prices[2447]={value=50,time=time()}
 P.live={{name='Elixir of Minor Defense',spell=7183,item=5997,profession='Alchemy',api='modern',mats={{id=765,count=1},{id=2447,count=1},{id=3371,count=1}},available=8,complete=true,output=1,live=true,difficulty='optimal',kind='live'}}
 P.char.recipes.Alchemy={s7183=P.live[1]}
end

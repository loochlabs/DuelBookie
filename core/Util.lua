--utils
local _,addon = ...
local Util = addon:NewModule("Util")

function Util:UtilPrint()
	addon:Debug("test print")
end

function Util:RGBToHex(r,g,b)
	return string.format("%02x%02x%02x",255*r, 255*g, 255*b)
end

--- Returns a color table for use with lib-st
-- @param class Global class name, i.e. "PRIEST"
function Util:GetClassColor(class)
	local color = RAID_CLASS_COLORS[class]
	if not color then
		color = {r=1,g=1,b=1,a=1}
	end
	return color
end

local function TitleCaseName(name)
   if not name then return "" end -- Just in case
   local realm
   if (strfind(name, "-", nil, true)) then
      name, realm = strsplit("-", name, 2)
   end
   name = name:lower():gsub("^%l", string.upper)
   return name .. "-" .. (realm or addon.realmName)
end

function Util:AddNameToList(list, name, class)
   local c = self:GetClassColor(class)
   list[name] = "|cff"..self:RGBToHex(c.r,c.g,c.b) .. tostring(name) .."|r"
end

-- Builds a list of targets we can sync to.
-- Used in the options menu for an AceGUI dropdown.
function Util:GetSyncTargetOptions()
   local name, isOnline, class, _
   local ret = {}
   -- target
   if UnitIsFriend("player", "target") and UnitIsPlayer("target") then
      self:AddNameToList(ret, addon:UnitName("target"), select(2, UnitClass("target")))
   end
   -- group
   for i = 1, GetNumGroupMembers() do
	   name, _, _, _, _, class, _, isOnline = GetRaidRosterInfo(i)
      if isOnline then self:AddNameToList(ret, tostring(name), class) end
   end
   -- friends
   for i = 1, C_FriendList.GetNumOnlineFriends() do
      name, _, class, _, isOnline = C_FriendList.GetFriendInfoByIndex(i)
      if isOnline then self:AddNameToList(ret, self:TitleCaseName(name), class) end
   end
   -- guildmembers
   for i = 1, GetNumGuildMembers() do
      name, _, _, _, _, _, _, _, isOnline,_,class = GetGuildRosterInfo(i)
      if isOnline then self:AddNameToList(ret, self:TitleCaseName(name), class) end
   end
   -- Remove ourselves
   --if not addon.debug then ret[addon.playerName] = nil end
   ret[addon.playerName] = nil
   -- Check if it's empty
   local isEmpty = true
   for k in pairs(ret) do isEmpty = false; break end
   ret[1] = isEmpty and "--"..L["No recipients available"].."--" or nil
   return ret
end
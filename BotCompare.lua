--[[ Definitions ]]
BotCompare = CreateFrame("Frame", "BotCompare", UIParent);

BINDING_HEADER_BOTCOMPARE = "BotCompare";

local ITEM_INFO_SLOT = 9;
local TOOLTIP_ITEM_LINK = 2;
local botSlotIds = {
	INVTYPE_WEAPON = 0,
	INVTYPE_2HWEAPON = 0,
	INVTYPE_WEAPONMAINHAND = 0,
	INVTYPE_WEAPONOFFHAND = 1,
	INVTYPE_SHIELD = 1,
	INVTYPE_HOLDABLE = 1,
	INVTYPE_RANGED = 2,
	INVTYPE_THROWN = 2,
	INVTYPE_RANGEDRIGHT = 2,
	INVTYPE_RELIC = 2,
	INVTYPE_HEAD = 3,
	INVTYPE_SHOULDER = 4,
	INVTYPE_CHEST = 5,
	INVTYPE_BODY = 5,
	INVTYPE_ROBE = 5,
	INVTYPE_WAIST = 6,
	INVTYPE_LEGS = 7,
	INVTYPE_FEET = 8,
	INVTYPE_WRIST = 9,
	INVTYPE_HAND = 10,
	INVTYPE_CLOAK = 11,
	INVTYPE_TABARD = 12,
	INVTYPE_FINGER = 13,
	-- INVTYPE_FINGER = 14,
	INVTYPE_TRINKET = 15,
	-- INVTYPE_TRINKET = 16,
	INVTYPE_NECK = 17,
};

--[[ Data ]]
local areBotsSynced = false;
local botItems = {};
local botCompareTooltips = {};

--[[ Locals ]]

local function addCompareTooltip(itemLink, index, leftToRight, botName)
	if (not itemLink or not index) then
		return;
	end

	local tooltip = botCompareTooltips[index];

	if (not tooltip) then
		tooltip = CreateFrame("GameTooltip", "CompareBotTooltip" .. index, UIParent, "ShoppingTooltipTemplate");
		botCompareTooltips[index] = tooltip;
	end

	local anchorTooltip;
	if (index > 1) then
		anchorTooltip = _G["CompareBotTooltip" .. (index-1)];
	else
		anchorTooltip = GameTooltip;
	end

	tooltip:SetOwner(anchorTooltip, "ANCHOR_NONE");
	if (leftToRight) then
		tooltip:SetPoint("TOPLEFT", anchorTooltip, "TOPRIGHT", 0, 0);
	else
		tooltip:SetPoint("TOPRIGHT", anchorTooltip, "TOPLEFT", 0, 0);
	end

	tooltip:SetHyperlink(itemLink);

	tooltip:AddLine("|cfff194f7" .. botName .. "'s Item");

	tooltip:Show();

	anchorTooltip = tooltip;
end

local function hidePlayerCompareTooltips(tooltip)
	if (not tooltip) then
		return;
	end

	local shoppingTooltip1, shoppingTooltip2, shoppingTooltip3 = unpack(tooltip.shoppingTooltips);
	shoppingTooltip1:Hide();
	shoppingTooltip2:Hide();
	shoppingTooltip3:Hide();
end

local function hideBotCompareTooltips()
	for _, tooltip in ipairs(botCompareTooltips) do
		tooltip:Hide();
	end
end

local function isUnitBot(name)
	return botItems[name] ~= nil;
end

local function getBotItem(name, slotId)
	if (not slotId or botItems[name] == nil) then
		return nil;
	end

	return botItems[name][slotId];
end

local function getBotCompareItems(botName, slot)
	local slotId = botSlotIds[slot];
	local botItem1 = getBotItem(botName, slotId);

	local botItem2 = nil;
	if (slot == "INVTYPE_FINGER" or slot == "INVTYPE_TRINKET" or slot == "INVTYPE_WEAPON") then
		botItem2 = getBotItem(botName, slotId+1);
	end

	return botItem1, botItem2;
end

local function syncAllBots()
	if (not areBotsSynced) then
		SendChatMessage(".bot sync");
		areBotsSynced = true;

		-- print ("Requested gear list for all bots.");
	end
end

--[[ Scripting Hooks ]]

local function onEvent(self, event, ...)
	if (event == "GOSSIP_CLOSED") then
		local targetName = UnitName("target");

		if (not isUnitBot(targetName)) then
			return;
		end

		areBotsSynced = false;
	end
end

local function onShowCompareItem()
	local targetName = UnitName("target");

	if (not targetName) then
		return;
	end

	if (not isUnitBot(targetName)) then
		return;
	end

	hidePlayerCompareTooltips(GameTooltip);
	hideBotCompareTooltips();

	local itemLink = select(TOOLTIP_ITEM_LINK, GameTooltip:GetItem());

	if (not itemLink) then
		return;
	end

	-- Figure out which direction to stack in
	local vLeftDist = GameTooltip:GetLeft() or 0;
	local vRightDist = GetScreenWidth() - (GameTooltip:GetRight() or 0);
	local leftToRight = vLeftDist < vRightDist

	local itemSlot = select(ITEM_INFO_SLOT, GetItemInfo(itemLink));
	local botItem1, botItem2 = getBotCompareItems(targetName, itemSlot);

	local counter = 0;
	if (botItem1 ~= nil) then
		addCompareTooltip(botItem1, counter+1, leftToRight, targetName);
		counter = counter + 1;
	end

	if (botItem2 ~= nil) then
		addCompareTooltip(botItem2, counter + 1, leftToRight, targetName);
		counter = counter + 1;
	end
end

local function onSystemMsgReceived(self, event, msg, ...)
	if (not msg:find("BOTCOMPARE:")) then
		return;
	end

	msg = string.gsub(msg, "BOTCOMPARE:", "");

	local name;
	local gearList = {};
	local counter = 1;

	local separator = ">";

	for word in string.gmatch(msg, "([^" .. separator .. "]+)") do
		if (counter > 1) then
			if (word ~= ' ') then
				gearList[counter-2] = word;
			else
				gearList[counter-2] = nil;
			end
		else
			name = word;
		end
		counter = counter + 1;
	end

	botItems[name] = gearList;

	-- print("Received gear list for " .. name .. ".");

	return true;
end

local function onUpdate(self)
	syncAllBots();
end

--[[ Register Hooks ]]
BotCompare:RegisterEvent("GOSSIP_CLOSED");
BotCompare:SetScript("OnEvent", onEvent);
BotCompare:SetScript("OnUpdate", onUpdate);
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", onSystemMsgReceived);
GameTooltip:HookScript("OnHide", hideBotCompareTooltips);
hooksecurefunc("GameTooltip_ShowCompareItem", onShowCompareItem);

--[[ Bindings ]]
function BotCompare:EquipCursorItem()
	local mouseFocus = GetMouseFocus();

	if (not mouseFocus) then
		return;
	end

	local focusName = mouseFocus:GetName();

	local pattern1 = (focusName or ""):match("ContainerFrame%d+Item%d+");
	local pattern2 = (focusName or ""):match("ContainerFrameBag%d+Slot%d+");
	local pattern3 = (focusName or ""):match("BagnonItemSlot%d+");

	if (not pattern1 and not pattern2 and not pattern3) then
		return;
	end

	local bagID, slotID = mouseFocus:GetParent():GetID(), mouseFocus:GetID()

	local alt = 0;
	if (IsAltKeyDown() ~= nil) then
		alt = 1;
	end

	SendChatMessage(".bot equip " .. bagID .. " " .. slotID .. " " .. alt);
end
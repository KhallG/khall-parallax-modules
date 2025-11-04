local MODULE = MODULE

MODULE.name = "Item Spawn Menu"
MODULE.author = "Rune Knight & Khall"
MODULE.description = "Adds a tab to the spawn menu for item spawning and the possibility to undo them."

CAMI.RegisterPrivilege({
    Name = "Parallax - Item Spawn Menu",
    MinAccess = "admin"
})

function MODULE:GetCategoryIcon(category)
    local icons = {
        ["Ammunition"] = "icon16/tab.png",
        ["Clothing"] = "icon16/user_suit.png",
        ["Consumables"] = "icon16/pill.png",
        ["Medical"] = "icon16/heart.png",
        ["misc"] = "icon16/error.png",
        ["Permits"] = "icon16/note.png",
        ["Storage"] = "icon16/package.png",
        ["Weapons"] = "icon16/gun.png",
    }
    
    return hook.Run("GetItemSpawnMenuIcons", category) or icons[category] or "icon16/folder.png"
end

if SERVER then
    util.AddNetworkString("ItemSpawn_Request")
    util.AddNetworkString("ItemGive_Request")

    ix.log.AddType("ItemSpawn_Request", function(client, itemName)
        return string.format("%s spawned the item: \"%s\".", client:GetCharacter():GetName(), tostring(itemName))
    end)

    net.Receive("ItemSpawn_Request", function(len, client)
        local uniqueID = net.ReadString()

        if not CAMI.PlayerHasAccess(client, "Parallax - Item Spawn Menu", nil) then return end

        for _, item in pairs(ix.item.list) do
            if item.uniqueID == uniqueID then
                ix.item.Spawn(item.uniqueID, client:GetShootPos() + client:GetAimVector() * 84 + Vector(0, 0, 16), function(item, entity)
                    if IsValid(entity) then
                        undo.Create(item.name)
                        undo.AddEntity(entity)
                        undo.SetPlayer(client)
                        undo.Finish()
                    end
                end)

                ix.log.Add(client, "ItemSpawn_Request", item.name)
                break
            end
        end
    end)

    net.Receive("ItemGive_Request", function(len, player)
        if not CAMI.PlayerHasAccess(player, "Parallax - Item Spawn Menu", nil) then return end

        local data = net.ReadString()
        if #data <= 0 then return end

        local uniqueID = data:lower()

        if not ix.item.list[uniqueID] then
            for k, v in SortedPairs(ix.item.list) do
                if ix.util.StringMatches(v.name, uniqueID) then
                    uniqueID = k
                    break
                end
            end
        end

        local success, error = player:GetCharacter():GetInventory():Add(uniqueID, 1)

        if success then
            player:NotifyLocalized("itemCreated")
        else
            player:NotifyLocalized(tostring(error))
        end
    end)
else
    function MODULE:InitializedPlugins()
        if SERVER then return end
        RunConsoleCommand("spawnmenu_reload")
    end

    spawnmenu.AddCreationTab("Items", function()
        local panel = vgui.Create("SpawnmenuContentPanel")
        local tree, nav = panel.ContentNavBar.Tree, panel.OldSpawnlists

        local categories = {}
        for uid, item in pairs(ix.item.list) do
            local category = item.category
            categories[category] = categories[category] or {}
            table.insert(categories[category], item)
        end

        for category, items in SortedPairs(categories) do
            local icon16 = MODULE:GetCategoryIcon(category)
            local node = tree:AddNode(L(category), icon16)
            node.DoClick = function(self)
                if self.PropPanel and IsValid(self.PropPanel) then 
                    self.PropPanel:Remove()
                    self.PropPanel = nil
                end

                self.PropPanel = vgui.Create("ContentContainer", panel)
                self.PropPanel:SetVisible(false)
                self.PropPanel:SetTriggerSpawnlistChange(false)

                for _, item in SortedPairsByMemberValue(items, "name") do
                    spawnmenu.CreateContentIcon("item", self.PropPanel, {
                        nicename = (item.GetName and item:GetName()) or item.name,
                        spawnname = item.uniqueID,
                    })
                end

                panel:SwitchPanel(self.PropPanel)
            end
        end

        local firstNode = tree:Root():GetChildNode(0)
        if IsValid(firstNode) then
            firstNode:InternalDoClick()
        end

        return panel
    end, "icon16/cog_add.png", 201)

    spawnmenu.AddContentType("item", function(panel, data)
        local name, uniqueID = data.nicename, data.spawnname
        local icon = vgui.Create("SpawnIcon", panel)
        icon:SetWide(64)
        icon:SetTall(64)
        icon:InvalidateLayout(true)

        local item = ix.item.list[uniqueID]

        icon:SetModel((item.GetModel and item:GetModel()) or item.model)
        icon:SetTooltip(name)

        icon.DoClick = function(self)
            surface.PlaySound("ui/buttonclickrelease.wav")
            if not CAMI.PlayerHasAccess(LocalPlayer(), "Parallax - Item Spawn Menu", nil) then 
                return
            end

            net.Start("ItemSpawn_Request")
            net.WriteString(uniqueID)
            net.SendToServer()
        end

        function icon:OpenMenu()
            local menu = DermaMenu()

            local copyOption = menu:AddOption("Copy Item ID", function()
                SetClipboardText(item.uniqueID)
            end)
            copyOption:SetIcon("icon16/page_copy.png")

            local giveOption = menu:AddOption("Give to Myself", function()
                net.Start("ItemGive_Request")
                net.WriteString(item.uniqueID)
                net.SendToServer()
            end)
            giveOption:SetIcon("icon16/user_add.png")

            local refreshOption = menu:AddOption("Refresh Icon", function()
                if IsValid(icon) then
                    icon:RebuildSpawnIcon()
                end
            end)
            refreshOption:SetIcon("icon16/arrow_refresh.png")

            menu:Open()
        end

        icon:InvalidateLayout(true)

        if IsValid(panel) then
            panel:Add(icon)
        end

        return icon
    end)
end

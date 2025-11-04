local MODULE = MODULE

MODULE.name = "C_Hands Generator"
MODULE.description = "Generates custom hands for players."
MODULE.author = "Khall"

if CLIENT then 
    local playerMeta = FindMetaTable("Player")
    local entMeta = FindMetaTable("Entity")
    
    local CGEN_mode = 3
    local CGEN_long = 0
    local cl_playermodel = GetConVar("cl_playermodel")

    local handsRootLong = {
        ['ValveBiped.Bip01_R_Clavicle'] = true,
        ['ValveBiped.Bip01_L_Clavicle'] = true,
    }

    local handsRoot = {
        ['ValveBiped.Bip01_R_UpperArm'] = true,
        ['ValveBiped.Bip01_L_UpperArm'] = true,
    }

    local CGEN_CurHandsModel = ""
    local CGEN_CurHandsSkin = 0
    local CGEN_CurHandsBGs = {}
    local CGEN_CurTime = CurTime()
    local CGEN_BoneDraw = false
    local CGEN_ForceReload = false
    local CGEN_RootBones = {}
    local CGEN_HandBones = {}

    function entMeta:GetAllChildBones(bone)
        local tab = {}
        local bones = self:GetChildBones(bone)
        local lastBoneBranch = bone

        for i = 1, #bones do    
            local b = bones[i]
            local lastBone = b

            tab[self:GetBoneName(b)] = true
            
            for j = 0, self:GetBoneCount() - 1 do
                local bParent = self:GetBoneParent(j)

                if bParent == lastBone or bParent == lastBoneBranch or tab[self:GetBoneName(bParent)] then
                    local treeBone = self:GetChildBones(j)
                    tab[self:GetBoneName(j)] = true
                    lastBone = j
                    if treeBone and #treeBone > 1 then 
                        lastBoneBranch = j 
                    end
                end
            end
        end

        return tab
    end

    function playerMeta:CGENGetDefaultHands()
        local playerModel = self:GetModel()
        local playerModelName = player_manager.TranslateToPlayerModelName(playerModel)
        local data = player_manager.TranslatePlayerHands(playerModelName)

        data.model = tostring(data.model)
        data.skin = tonumber(data.skin)
        data.body = tostring(data.body)

        return data
    end

    function MODULE:OutfitApply(ply, model, download_info)
        ply.m_sCGENForcedModel = model != "" and model or nil

        if model == "" then 
            ply:SetModel(ply.original_model or player_manager.TranslatePlayerModel(cl_playermodel:GetString())) 
        end 
    end

    local function CGEN_HandsDraw(self)
        local ply = LocalPlayer()

        if CGEN_CurTime != CurTime() then 
            self:SetModel(self:GetModel()) 
        end
        
        local plySkin = ply:GetSkin()
        local skinChanged = (CGEN_CurHandsSkin != plySkin)
        local bgChanged = false
        
        for i = 0, ply:GetNumBodyGroups() - 1 do
            local currentBG = ply:GetBodygroup(i)
            if CGEN_CurHandsBGs[i] != currentBG then
                bgChanged = true
                break
            end
        end
        
        if CGEN_ForceReload or (CGEN_CurHandsModel and CGEN_CurHandsModel != self:GetModel()) or skinChanged or bgChanged then
            CGEN_ForceReload = false
            CGEN_BoneDraw = false

            local data = ply:CGENGetDefaultHands()
            local plyModel = ply:GetModel()

            if CGEN_mode == 3 or not data or data.model == plyModel then 
                CGEN_RootBones = (CGEN_long == 1) and handsRootLong or handsRoot
                CGEN_HandBones = {}

                self:SetModel(ply:GetModel())
                self:SetSkin(ply:GetSkin())
                self:SetColor(ply:GetPlayerColor():ToColor())

                for i = 0, ply:GetNumBodyGroups() - 1 do
                    if self:GetBodygroupCount(i) > 0 then
                        self:SetBodygroup(i, ply:GetBodygroup(i)) 
                    end
                end

                local hasHandsRoot = false
                for i = 0, self:GetBoneCount() - 1 do
                    local bName = self:GetBoneName(i)
                    if CGEN_RootBones[bName] then
                        hasHandsRoot = true
                        break
                    end
                end

                if not hasHandsRoot then
                    local defaultData = ply:CGENGetDefaultHands()
                    if defaultData and defaultData.model then
                        self:SetModel(defaultData.model)
                        self:SetSkin(defaultData.skin)
                        self:SetBodyGroups(defaultData.body)
                        CGEN_BoneDraw = false
                    else
                        CGEN_BoneDraw = true
                    end
                else
                    for i = 0, self:GetBoneCount() - 1 do
                        local bName = self:GetBoneName(i)
                        
                        if CGEN_RootBones[bName] then
                            CGEN_HandBones[bName] = true
                            table.Merge(CGEN_HandBones, self:GetAllChildBones(i))
                        end
                    end

                    CGEN_BoneDraw = true
                end
            else
                self:SetModel(data.model)
                self:SetSkin(data.skin)
                self:SetBodyGroups(data.body)
            end

            CGEN_CurHandsModel = self:GetModel()
            CGEN_CurHandsSkin = plySkin
            
            for i = 0, ply:GetNumBodyGroups() - 1 do
                CGEN_CurHandsBGs[i] = ply:GetBodygroup(i)
            end
        end

        if CGEN_BoneDraw then
            local nan = 0/0
            local nanVec = Vector(nan, nan, nan)

            for i = 0, self:GetBoneCount() - 1 do
                local bName = self:GetBoneName(i)

                if not CGEN_HandBones[bName] then 
                    self:ManipulateBoneScale(i, nanVec)
                else
                    self:ManipulateBoneScale(i, Vector(1, 1, 1))
                end
            end

            self:DrawModel()
            
            CGEN_CurTime = CurTime()
        else 
            self:DrawModel() 
        end
    end

    function MODULE:PostDrawPlayerHands(ent, vm, ply, wep)
        if CurTime() - CGEN_CurTime >= 0.1 then
            ent.Draw = function() 
                CGEN_HandsDraw(ent)
            end
        end
    end
end
Config = Config or exports["Enzo-GangSiegeX"]:GetConfig()
local serverState = {
    framework = Config.Framework:lower(),
    QBCore = (Config.Framework:lower() == "qb" and exports["qb-core"]:GetCoreObject() or nil),
    QBX = (Config.Framework:lower() == "qbox" and exports["qbx_core"] or nil),
    targetSystem = Config.TargetSystem:lower() == "qb" and "qb-target" or "ox_target",
    notifySystem = Config.NotifySystem:lower(),
    CoreData = {
        Zones = {},
        Players = {},
        Entities = {},
        Cooldowns = {},
        Cache = {ZoneLookup = {}}
    },
    isValid = nil
}

local function computeStealthKey()
    local resource = GetCurrentResourceName()
    local e1 = string.char(69, 110, 122, 111)
    local e2 = string.char(45, 71, 97, 110, 103)
    local e3 = string.char(83, 105, 101, 103, 101, 88)
    local expected = e1 .. e2 .. e3
    local stealthKey = 42

    for i = 1, #resource do
        stealthKey = stealthKey + (string.byte(resource, i) or 0) - (string.byte(expected, i) or 0)
    end

    return stealthKey == 42
end

serverState.isValid = computeStealthKey()

local function GetPlayer(src)
    if not serverState.isValid then
        return nil
    end
    if serverState.framework == "qb" then
        return serverState.QBCore.Functions.GetPlayer(src)
    elseif serverState.framework == "qbox" then
        return exports["qbx_core"]:GetPlayer(src)
    end
    return nil
end

local function notifyClient(src, title, desc, typ, duration)
    if not serverState.isValid then
        return
    end
    if serverState.notifySystem == "qb" and serverState.QBCore then
        local message = title and desc and (title .. ": " .. desc) or desc or title
        serverState.QBCore.Functions.Notify(src, message, typ or "info", duration or 5000)
    else
        TriggerClientEvent("Enzo-GangSiegeX:notify", src, typ or "inform", desc, title, duration or 5000)
    end
end

local function initializeCoreData()
    if not serverState.isValid then
        serverState.CoreData.Zones = {["dummy"] = {}}
        return
    end
    local success, err =
        pcall(
        function()
            MySQL.query.await(
                [[ 
            CREATE TABLE IF NOT EXISTS siege_zones (
                zone_id VARCHAR(50) PRIMARY KEY,
                gang_owner VARCHAR(50) DEFAULT 'CIVILIAN',
                last_captured BIGINT DEFAULT 0
            )
        ]]
            )
            MySQL.query.await(
                [[ 
            CREATE TABLE IF NOT EXISTS siege_players (
                license VARCHAR(50) PRIMARY KEY,
                xp INT DEFAULT 0,
                level INT DEFAULT 1,
                last_gangster_spawn BIGINT DEFAULT 0,
                gangster_count INT DEFAULT 0
            )
        ]]
            )
            MySQL.query.await(
                [[ 
            CREATE TABLE IF NOT EXISTS siege_cooldowns (
                id VARCHAR(100) PRIMARY KEY,
                expiration BIGINT NOT NULL
            )
        ]]
            )
        end
    )
    if not success then
        StopResource(GetCurrentResourceName())
        return
    end
    local zonesResult = MySQL.query.await("SELECT * FROM siege_zones") or {}
    local playersResult = MySQL.query.await("SELECT * FROM siege_players") or {}
    local cooldownsResult = MySQL.query.await("SELECT * FROM siege_cooldowns") or {}
    local zonesById = {}
    for _, zone in ipairs(zonesResult) do
        zonesById[zone.zone_id] = {gang_owner = zone.gang_owner, last_captured = zone.last_captured}
    end
    serverState.CoreData.Zones = zonesById
    local playersByLicense = {}
    for _, player in ipairs(playersResult) do
        playersByLicense[player.license] = {
            xp = player.xp,
            level = player.level,
            last_gangster_spawn = player.last_gangster_spawn,
            gangster_count = player.gangster_count,
            capturingZone = nil
        }
    end
    serverState.CoreData.Players = playersByLicense
    serverState.CoreData.Cooldowns = {}
    for _, cd in ipairs(cooldownsResult) do
        serverState.CoreData.Cooldowns[cd.id] = cd.expiration
    end
    for zoneId, zoneData in pairs(Config.Turf.Data) do
        serverState.CoreData.Cache.ZoneLookup[zoneId] = {
            coords = zoneData.center,
            radius = Config.Turf.Defaults.radius or 50
        }
        if not serverState.CoreData.Zones[zoneId] then
            serverState.CoreData.Zones[zoneId] = {gang_owner = "CIVILIAN", last_captured = 0}
            MySQL.query.await(
                "INSERT IGNORE INTO siege_zones (zone_id, gang_owner) VALUES (?, ?)",
                {zoneId, "CIVILIAN"}
            )
        end
        GlobalState["zone:" .. zoneId] = serverState.CoreData.Zones[zoneId].gang_owner
    end
    TriggerClientEvent("Enzo-GangSiegeX:syncZones", -1, serverState.CoreData.Zones)
end

function serverState.CoreData:GetZone(zoneId)
    if not serverState.isValid then
        return nil
    end
    return self.Zones[zoneId]
end

function serverState.CoreData:SetZoneOwner(zoneId, gang)
    if not serverState.isValid then
        return
    end
    self.Zones[zoneId].gang_owner = gang
    self.Zones[zoneId].last_captured = GetGameTimer()
    MySQL.update(
        "UPDATE siege_zones SET gang_owner = ?, last_captured = ? WHERE zone_id = ?",
        {gang, self.Zones[zoneId].last_captured, zoneId}
    )
    GlobalState["zone:" .. zoneId] = gang
    TriggerClientEvent("Enzo-GangSiegeX:syncZones", -1, {[zoneId] = self.Zones[zoneId]})
end

function serverState.CoreData:GetCurrentZone(coords)
    if not serverState.isValid then
        return nil, nil
    end
    for zoneId, data in pairs(self.Cache.ZoneLookup) do
        if #(coords - data.coords) < data.radius then
            return zoneId, self.Zones[zoneId]
        end
    end
    return nil, nil
end

function serverState.CoreData:GetPlayer(src)
    if not serverState.isValid then
        return nil
    end
    local player = GetPlayer(src)
    if not player then
        return nil
    end
    local license = player.PlayerData.license
    if not self.Players[license] then
        self.Players[license] = {
            xp = 0,
            level = 1,
            last_gangster_spawn = 0,
            gangster_count = 0,
            capturingZone = nil
        }
        MySQL.insert("INSERT INTO siege_players (license) VALUES (?)", {license})
    end
    return self.Players[license]
end

function serverState.CoreData:UpdatePlayerXP(src, xpGain)
    if not serverState.isValid then
        return
    end
    local playerData = self:GetPlayer(src)
    if not playerData then
        return
    end
    playerData.xp = playerData.xp + xpGain
    while playerData.xp >= Config.RobberySettings.xpPerLevel * playerData.level and
        playerData.level < Config.RobberySettings.maxLevel do
        playerData.xp = playerData.xp - (Config.RobberySettings.xpPerLevel * playerData.level)
        playerData.level = playerData.level + 1
        notifyClient(src, "Level Up", "You've reached level " .. playerData.level .. "!", "success")
    end
    local player = GetPlayer(src)
    MySQL.update(
        "UPDATE siege_players SET xp = ?, level = ? WHERE license = ?",
        {playerData.xp, playerData.level, player.PlayerData.license}
    )
end

function serverState.CoreData:SetGangsterCount(src, count)
    if not serverState.isValid then
        return
    end
    local playerData = self:GetPlayer(src)
    if not playerData then
        return
    end
    playerData.gangster_count = count
    playerData.last_gangster_spawn = GetGameTimer()
    local player = GetPlayer(src)
    MySQL.update(
        "UPDATE siege_players SET gangster_count = ?, last_gangster_spawn = ? WHERE license = ?",
        {count, playerData.last_gangster_spawn, player.PlayerData.license}
    )
end

function serverState.CoreData:SetCooldown(type, identifier, duration)
    if not serverState.isValid then
        return
    end
    local id = type .. ":" .. identifier
    self.Cooldowns[id] = GetGameTimer() + (duration * 1000)
    MySQL.insert(
        "INSERT INTO siege_cooldowns (id, expiration) VALUES (?, ?) ON DUPLICATE KEY UPDATE expiration = ?",
        {id, self.Cooldowns[id], self.Cooldowns[id]}
    )
end

function serverState.CoreData:GetCooldown(type, identifier)
    if not serverState.isValid then
        return 0
    end
    local id = type .. ":" .. identifier
    local expiration = self.Cooldowns[id]
    if expiration and expiration > GetGameTimer() then
        return math.ceil((expiration - GetGameTimer()) / 1000)
    end
    self.Cooldowns[id] = nil
    MySQL.query("DELETE FROM siege_cooldowns WHERE id = ?", {id})
    return 0
end

function serverState.CoreData:SetPlayerCapturing(src, zoneId)
    if not serverState.isValid then
        return
    end
    local playerData = self:GetPlayer(src)
    if not playerData then
        return
    end
    if zoneId then
        playerData.capturingZone = {zoneId = zoneId, startTime = GetGameTimer()}
        Player(src).state:set("capturingZone", true, true)
        TriggerClientEvent("Enzo-GangSiegeX:startCapture", src, zoneId)
    else
        local oldZoneId = playerData.capturingZone and playerData.capturingZone.zoneId
        playerData.capturingZone = nil
        Player(src).state:set("capturingZone", nil, true)
        if oldZoneId then
            TriggerClientEvent("Enzo-GangSiegeX:abortCapture", src, oldZoneId)
        end
    end
end

function serverState.CoreData:RegisterEntity(entity, data)
    if not serverState.isValid then
        return
    end
    self.Entities[entity] = data
    if data.type == "gangster" then
        Entity(entity).state:set("owner", data.owner, true)
        Entity(entity).state:set("gang", data.gang, true)
    elseif data.type == "dialog" then
        Entity(entity).state:set("zone", data.zone, false)
    elseif data.type == "goon" then
        Entity(entity).state:set("zone", data.zone, true)
        Entity(entity).state:set("gang", data.gang, true)
    end
end

function serverState.CoreData:UnregisterEntity(entity)
    if not serverState.isValid then
        return
    end
    self.Entities[entity] = nil
    Entity(entity).state:set("owner", nil, true)
    Entity(entity).state:set("gang", nil, true)
    Entity(entity).state:set("zone", nil, false)
end

RegisterServerEvent(
    "Enzo-GangSiegeX:requestZones",
    function()
        if not serverState.isValid then
            return
        end
        local src = source
        TriggerClientEvent("Enzo-GangSiegeX:syncZones", src, serverState.CoreData.Zones)
    end
)

RegisterServerEvent(
    "Enzo-GangSiegeX:requestDialogPed",
    function(id, playerCoords)
        if not serverState.isValid then
            return
        end
        local src = source
        local cooldown = serverState.CoreData:GetCooldown("dialog", src)
        if cooldown > 0 then
            return
        end
        local zone = Config.Turf.Data[id]
        if not zone or not zone.npc then
            notifyClient(src, "System", "Invalid configuration.", "error")
            return
        end
        local pedCoords = zone.npc
        if #(playerCoords - vector3(pedCoords.x, pedCoords.y, pedCoords.z)) > 500 then
            return
        end

        -- Check if dialog ped already exists for this zone
        for entity, data in pairs(serverState.CoreData.Entities) do
            if data.type == "dialog" and data.zone == id and DoesEntityExist(entity) then
                local netId = NetworkGetNetworkIdFromEntity(entity)
                -- Sync only to players within 500 units
                for _, playerId in ipairs(GetPlayers()) do
                    local playerPed = GetPlayerPed(playerId)
                    local playerPos = GetEntityCoords(playerPed)
                    if #(playerPos - vector3(pedCoords.x, pedCoords.y, pedCoords.z)) <= 500 then
                        TriggerClientEvent("Enzo-GangSiegeX:syncDialogPed", playerId, netId, id, pedCoords)
                    end
                end
                return
            end
        end

        local controllingGang =
            serverState.CoreData.Zones[id] and serverState.CoreData.Zones[id].gang_owner or "default"
        local gangConfig =
            Config.Turf.Defaults.gangster.types[controllingGang] or Config.Turf.Defaults.gangster.types["default"]
        local pedModel = gangConfig.skin
        local ped = CreatePed(4, GetHashKey(pedModel), pedCoords.x, pedCoords.y, pedCoords.z, pedCoords.w, true, false)
        if not ped then
            notifyClient(src, "System", "Failed to spawn capo.", "error")
            return
        end
        local netId = NetworkGetNetworkIdFromEntity(ped)
        serverState.CoreData:RegisterEntity(ped, {type = "dialog", zone = id})

        -- Sync to players within 500 units
        for _, playerId in ipairs(GetPlayers()) do
            local playerPed = GetPlayerPed(playerId)
            local playerPos = GetEntityCoords(playerPed)
            if #(playerPos - vector3(pedCoords.x, pedCoords.y, pedCoords.z)) <= 500 then
                TriggerClientEvent("Enzo-GangSiegeX:syncDialogPed", playerId, netId, id, pedCoords)
            end
        end
        serverState.CoreData:SetCooldown("dialog", src, 5)
    end
)

RegisterServerEvent(
    "Enzo-GangSiegeX:interactDialogPed",
    function(zoneId)
        if not serverState.isValid then
            return
        end
        local src = source
        notifyClient(src, "Dialog", "You spoke to the capo of " .. zoneId, "inform")
    end
)

RegisterServerEvent(
    "Enzo-GangSiegeX:attemptCapture",
    function(zoneId, playerCoords)
        if not serverState.isValid then
            return
        end
        local src = source
        local player = GetPlayer(src)
        if not player then
            return
        end
        local playerGang = player.PlayerData.gang and player.PlayerData.gang.name or "CIVILIAN"
        local zone = serverState.CoreData:GetZone(zoneId)
        if not zone then
            notifyClient(src, "Turf Alert", "Invalid turf.", "error")
            return
        end
        local coords =
            type(playerCoords) == "table" and vector3(playerCoords.x, playerCoords.y, playerCoords.z) or playerCoords
        if #(coords - Config.Turf.Data[zoneId].center) > Config.Turf.Defaults.radius then
            notifyClient(src, "Territory Alert", "Too far from territory.", "error")
            return
        end
        if zone.gang_owner == playerGang then
            notifyClient(src, "Turf Alert", "Territory already controlled.", "error")
            return
        end
        local cooldown = serverState.CoreData:GetCooldown("capture", src)
        if cooldown > 0 then
            notifyClient(src, "Turf Alert", "Capture on cooldown. Wait " .. cooldown .. " seconds.", "error")
            return
        end
        local playerData = serverState.CoreData:GetPlayer(src)
        if playerData.capturingZone then
            local elapsed = (GetGameTimer() - playerData.capturingZone.startTime) / 1000
            if elapsed > (Config.Turf.Defaults.captureTime / 1000) + 10 then
                serverState.CoreData:SetPlayerCapturing(src, nil)
            else
                notifyClient(src, "Turf Alert", "Already capturing a turf.", "error")
                return
            end
        end
        serverState.CoreData:SetPlayerCapturing(src, zoneId)
        TriggerClientEvent("Enzo-GangSiegeX:syncCaptures", -1)
        TriggerClientEvent("Enzo-GangSiegeX:notify", -1, "warning", "Shooters are enroute to " .. zoneId .. ".", 5000)
        Citizen.CreateThread(
            function()
                Wait(10000)
                if serverState.isValid and serverState.CoreData:GetPlayer(src).capturingZone then
                    TriggerEvent("Enzo-GangSiegeX:notifyGangstersOfCapture", zoneId, src)
                end
            end
        )
        Citizen.CreateThread(
            function()
                while true do
                    Wait(1000)
                    if not serverState.isValid then
                        return
                    end
                    local playerData = serverState.CoreData:GetPlayer(src)
                    local cap = playerData.capturingZone
                    if not cap then
                        break
                    end
                    local elapsed = (GetGameTimer() - cap.startTime) / 1000
                    local ped = GetPlayerPed(src)
                    local coords = GetEntityCoords(ped)
                    if
                        not DoesEntityExist(ped) or
                            #(coords - Config.Turf.Data[zoneId].center) > Config.Turf.Defaults.radius
                     then
                        notifyClient(src, "Turf Capture", "Capture aborted due to distance or entity error.", "error")
                        serverState.CoreData:SetPlayerCapturing(src, nil)
                        TriggerClientEvent("Enzo-GangSiegeX:syncCaptures", -1)
                        return
                    elseif elapsed >= (Config.Turf.Defaults.captureTime / 1000) then
                        serverState.CoreData:SetZoneOwner(zoneId, playerGang)
                        notifyClient(src, "Turf Capture", "Turf secured.", "success")
                        serverState.CoreData:SetPlayerCapturing(src, nil)
                        serverState.CoreData:SetCooldown("capture", src, Config.Turf.Defaults.captureCooldown)
                        TriggerClientEvent("Enzo-GangSiegeX:syncCaptures", -1)
                        return
                    end
                end
            end
        )
    end
)

RegisterServerEvent(
    "Enzo-GangSiegeX:validateCrafting",
    function(zoneId)
        if not serverState.isValid then
            return
        end
        local src = source
        local player = GetPlayer(src)
        if not player then
            return
        end
        local playerGang = player.PlayerData.gang and player.PlayerData.gang.name or "CIVILIAN"
        if not serverState.CoreData:GetZone(zoneId) or serverState.CoreData.Zones[zoneId].gang_owner ~= playerGang then
            notifyClient(src, "Access Denied", "Turf not controlled.", "error")
            return
        end
        if not Config.Crafting.enabled then
            notifyClient(src, "Crafting", "Crafting is disabled.", "error")
            return
        end
        TriggerClientEvent("Enzo-GangSiegeX:openCrafting", src, zoneId)
    end
)

RegisterServerEvent(
    "Enzo-GangSiegeX:craftItem",
    function(zoneId, recipeIndex)
        if not serverState.isValid then
            return
        end
        local src = source
        local player = GetPlayer(src)
        if not player then
            return
        end
        local playerGang = player.PlayerData.gang and player.PlayerData.gang.name or "CIVILIAN"
        if not serverState.CoreData:GetZone(zoneId) or serverState.CoreData.Zones[zoneId].gang_owner ~= playerGang then
            notifyClient(src, "Crafting", "You don’t control this turf.", "error")
            return
        end
        local recipe = Config.Crafting.recipes[recipeIndex]
        if not recipe then
            notifyClient(src, "Crafting", "Invalid recipe.", "error")
            return
        end
        if Config.Crafting.system == "ox" and exports.ox_inventory then
            for _, input in pairs(recipe.inputs) do
                local itemCount = exports.ox_inventory:Search(src, "count", input.item)
                if itemCount < input.amount then
                    notifyClient(
                        src,
                        "Crafting",
                        "Missing " .. input.amount - itemCount .. " " .. input.item .. ".",
                        "error"
                    )
                    return
                end
            end
            for _, input in pairs(recipe.inputs) do
                exports.ox_inventory:RemoveItem(src, input.item, input.amount)
            end
            if exports.ox_inventory:CanCarryItem(src, recipe.output, 1) then
                exports.ox_inventory:AddItem(src, recipe.output, 1)
                notifyClient(src, "Crafting", "Crafted " .. recipe.output .. ".", "success")
            else
                notifyClient(src, "Crafting", "Not enough inventory space.", "error")
                for _, input in pairs(recipe.inputs) do
                    exports.ox_inventory:AddItem(src, input.item, input.amount)
                end
            end
        else
            for _, reward in pairs(Config.RobberySettings.rewards or {}) do
                if math.random(100) <= reward.chance then
                    player.Functions.AddItem(reward.item, 1)
                    TriggerClientEvent(
                        "inventory:client:ItemBox",
                        src,
                        serverState.QBCore.Shared.Items[reward.item],
                        "add"
                    )
                end
            end
        end
    end
)

RegisterServerEvent(
    "Enzo-GangSiegeX:spawnGangster",
    function(coords)
        if not serverState.isValid then
            return
        end
        local src = source
        local player = GetPlayer(src)
        if not player then
            return
        end
        local playerGang = player.PlayerData.gang and player.PlayerData.gang.name or "CIVILIAN"
        local zoneId, zone = serverState.CoreData:GetCurrentZone(coords)
        if not zoneId or zone.gang_owner ~= playerGang then
            notifyClient(src, "Unit Deployment", "Not in controlled turf.", "error")
            return
        end
        local playerData = serverState.CoreData:GetPlayer(src)
        local cooldown = serverState.CoreData:GetCooldown("gangster", src)
        if cooldown > 0 then
            notifyClient(src, "Unit Deployment", "Cooldown active. Wait " .. cooldown .. " seconds.", "error")
            return
        end
        if playerData.gangster_count >= Config.Turf.Defaults.gangster.maxPerPlayer then
            notifyClient(src, "Unit Deployment", "Maximum units deployed.", "error")
            return
        end
        local model =
            Config.Turf.Defaults.gangster.types[playerGang] and Config.Turf.Defaults.gangster.types[playerGang].skin or
            Config.Turf.Defaults.gangster.types["default"].skin
        local ped = CreatePed(4, GetHashKey(model), coords.x, coords.y, coords.z, 0.0, true, false)
        if not ped or not DoesEntityExist(ped) then
            notifyClient(src, "Unit Deployment", "Failed to deploy unit.", "error")
            return
        end
        local netId = NetworkGetNetworkIdFromEntity(ped)
        local attempts = 0
        local maxAttempts = 10
        while not NetworkGetEntityOwner(ped) and attempts < maxAttempts do
            Wait(100)
            attempts = attempts + 1
        end
        if not NetworkGetEntityOwner(ped) then
            DeleteEntity(ped)
            notifyClient(src, "Unit Deployment", "Failed to sync unit to network. Try again.", "error")
            return
        end
        serverState.CoreData:RegisterEntity(ped, {type = "gangster", owner = src, gang = playerGang})
        TriggerClientEvent("Enzo-GangSiegeX:modifyGangster", src, {netId}, playerGang)
        serverState.CoreData:SetGangsterCount(src, playerData.gangster_count + 1)
        serverState.CoreData:SetCooldown("gangster", src, Config.Turf.Defaults.gangster.cooldown)
    end
)

RegisterServerEvent(
    "Enzo-GangSiegeX:removeGangsters",
    function()
        if not serverState.isValid then
            return
        end
        local src = source
        local count = 0
        for entity, data in pairs(serverState.CoreData.Entities) do
            if data.type == "gangster" and data.owner == src and DoesEntityExist(entity) then
                DeleteEntity(entity)
                serverState.CoreData:UnregisterEntity(entity)
                count = count + 1
            end
        end
        serverState.CoreData:SetGangsterCount(src, 0)
        serverState.CoreData:SetCooldown("gangster", src, 0)
    end
)

RegisterServerEvent(
    "Enzo-GangSiegeX:validateGangsterEngage",
    function(playerCoords, targetNetId)
        if not serverState.isValid then
            return
        end
        local src = source
        local player = GetPlayer(src)
        if not player then
            return
        end
        local playerGang = player.PlayerData.gang and player.PlayerData.gang.name or "CIVILIAN"
        local zoneId, zone = serverState.CoreData:GetCurrentZone(playerCoords)
        if not zoneId or zone.gang_owner ~= playerGang then
            notifyClient(src, "Unit Command", "Must be in controlled turf to engage units.", "error")
            return
        end
        local playerData = serverState.CoreData:GetPlayer(src)
        if playerData.gangster_count == 0 then
            notifyClient(src, "Unit Command", "No gangster units deployed.", "error")
            return
        end
        local target = targetNetId and NetworkGetEntityFromNetworkId(targetNetId) or nil
        if target and DoesEntityExist(target) then
            local targetOwner = NetworkGetEntityOwner(target)
            if targetOwner then
                local targetGang = Player(targetOwner).state.gang or "CIVILIAN"
                if targetGang == playerGang or targetGang == "CIVILIAN" then
                    notifyClient(src, "Unit Command", "Cannot engage friendly or civilian targets.", "error")
                    return
                end
            end
        end
        TriggerClientEvent("Enzo-GangSiegeX:engageGangsters", src, zoneId, zone.gang_owner, targetNetId)
    end
)

RegisterServerEvent(
    "Enzo-GangSiegeX:validateRobbery",
    function(robberyName, coords)
        if not serverState.isValid then
            return
        end
        local src = source
        local robbery = nil
        for _, point in pairs(Config.Interact.Locations.Robbery or {}) do
            if point[1] == robberyName then
                robbery = point
                break
            end
        end
        if not robbery or #(coords - robbery[2]) > 3.0 then
            notifyClient(src, "Interaction", "Move closer.", "error")
            return
        end
        local cooldown = serverState.CoreData:GetCooldown("robbery", robberyName)
        if cooldown > 0 then
            notifyClient(src, "Interaction", "This spot is on cooldown. Wait " .. cooldown .. " seconds.", "error")
            return
        end
        TriggerClientEvent("Enzo-GangSiegeX:playInteractionAnimation", src, robbery)
    end
)

RegisterServerEvent(
    "Enzo-GangSiegeX:attemptReward",
    function(robberyName)
        if not serverState.isValid then
            return
        end
        local src = source
        local player = GetPlayer(src)
        if not player then
            return
        end
        serverState.CoreData:SetCooldown("robbery", robberyName, Config.RobberySettings.cooldown)
        local playerData = serverState.CoreData:GetPlayer(src)
        if not playerData then
            return
        end
        local maxRewards =
            playerData.level == 1 and Config.RobberySettings.maxRewards[1] or Config.RobberySettings.maxRewards[2]
        local rewardsGiven = {}
        if Config.Crafting.system == "ox" and exports.ox_inventory then
            for _, reward in pairs(Config.RobberySettings.rewards or {}) do
                if #rewardsGiven >= maxRewards then
                    break
                end
                if math.random(100) <= reward.chance then
                    if exports.ox_inventory:CanCarryItem(src, reward.item, 1) then
                        exports.ox_inventory:AddItem(src, reward.item, 1)
                        table.insert(rewardsGiven, {item = reward.item, chance = reward.chance})
                    end
                end
            end
        else
            for _, reward in pairs(Config.RobberySettings.rewards or {}) do
                if #rewardsGiven >= maxRewards then
                    break
                end
                if math.random(100) <= reward.chance then
                    player.Functions.AddItem(reward.item, 1)
                    TriggerClientEvent(
                        "inventory:client:ItemBox",
                        src,
                        serverState.QBCore.Shared.Items[reward.item],
                        "add"
                    )
                    table.insert(rewardsGiven, {item = reward.item, chance = reward.chance})
                end
            end
        end
        serverState.CoreData:UpdatePlayerXP(src, Config.RobberySettings.xpGain)
        if #rewardsGiven > 0 then
            TriggerClientEvent(
                "Enzo-GangSiegeX:receiveRobberyReward",
                src,
                rewardsGiven,
                playerData.xp,
                playerData.level
            )
        else
            notifyClient(
                src,
                "Operation",
                "No shit this time. XP: " .. playerData.xp .. " | Level: " .. playerData.level,
                "inform",
                7000
            )
        end
    end
)

RegisterServerEvent(
    "Enzo-GangSiegeX:syncGangsterPosition",
    function(netId, coords)
        if not serverState.isValid then
            return
        end
        local src = source
        local entity = NetworkGetEntityFromNetworkId(netId)
        if
            DoesEntityExist(entity) and serverState.CoreData.Entities[entity] and
                serverState.CoreData.Entities[entity].owner == src
         then
            TriggerClientEvent("Enzo-GangSiegeX:updateGangsterPosition", -1, netId, coords)
        elseif not DoesEntityExist(entity) then
            serverState.CoreData:UnregisterEntity(entity)
        end
    end
)

RegisterServerEvent(
    "Enzo-GangSiegeX:syncGangsterFollow",
    function(netId, offsetX, offsetY)
        if not serverState.isValid then
            return
        end
        local src = source
        local entity = NetworkGetEntityFromNetworkId(netId)
        if
            DoesEntityExist(entity) and serverState.CoreData.Entities[entity] and
                serverState.CoreData.Entities[entity].owner == src
         then
            TriggerClientEvent("Enzo-GangSiegeX:updateGangsterFollow", -1, netId, offsetX, offsetY)
        elseif not DoesEntityExist(entity) then
            serverState.CoreData:UnregisterEntity(entity)
        end
    end
)

RegisterServerEvent(
    "Enzo-GangSiegeX:notifyGangstersOfCapture",
    function(zoneId, attackerSrc)
        if not serverState.isValid then
            return
        end
        local controllingGang = serverState.CoreData.Zones[zoneId].gang_owner
        local gangConfig =
            Config.Turf.Defaults.gangster.types[controllingGang] or Config.Turf.Defaults.gangster.types["default"]
        local waveConfig = Config.Turf.Data[zoneId].waves or Config.Turf.Defaults.waves
        if not waveConfig then
            return
        end
        local spawnLocs = waveConfig.locations or {Config.Turf.Data[zoneId].center}
        local spawnedNetIds = {}
        local weaponHash = GetHashKey(waveConfig.weapon or Config.Turf.Defaults.waves.weapon)
        for _, loc in pairs(spawnLocs) do
            for i = 1, waveConfig.countPerSpot do
                local ped =
                    CreatePed(
                    4,
                    GetHashKey(gangConfig.skin),
                    loc.x,
                    loc.y,
                    loc.z,
                    waveConfig.heading or 0.0,
                    true,
                    false
                )
                if ped then
                    GiveWeaponToPed(ped, weaponHash, 999, false, true)
                    SetCurrentPedWeapon(ped, weaponHash, true)
                    SetPedAmmo(ped, weaponHash, 999)
                    local netId = NetworkGetNetworkIdFromEntity(ped)
                    serverState.CoreData:RegisterEntity(ped, {type = "goon", zone = zoneId, gang = controllingGang})
                    table.insert(spawnedNetIds, netId)
                end
            end
        end
        if #spawnedNetIds > 0 then
            TriggerClientEvent("Enzo-GangSiegeX:spawnGoon", -1, spawnedNetIds, zoneId, controllingGang, attackerSrc)
        end
    end
)

RegisterServerEvent(
    "Enzo-GangSiegeX:unregisterGoon",
    function(netId)
        if not serverState.isValid then
            return
        end
        local src = source
        local entity = NetworkGetEntityFromNetworkId(netId)
        if
            DoesEntityExist(entity) and serverState.CoreData.Entities[entity] and
                serverState.CoreData.Entities[entity].type == "goon"
         then
            serverState.CoreData:UnregisterEntity(entity)
            if DoesEntityExist(entity) then
                DeleteEntity(entity)
            end
        elseif not DoesEntityExist(entity) then
            serverState.CoreData:UnregisterEntity(entity)
        end
    end
)

RegisterServerEvent(
    "Enzo-GangSiegeX:abortCaptureDueToDeath",
    function()
        if not serverState.isValid then
            return
        end
        local src = source
        local playerData = serverState.CoreData:GetPlayer(src)
        if playerData.capturingZone then
            notifyClient(src, "Turf Capture", "Capture aborted due to death.", "error")
            serverState.CoreData:SetPlayerCapturing(src, nil)
            TriggerClientEvent("Enzo-GangSiegeX:syncCaptures", -1)
        end
    end
)

AddEventHandler(
    "onResourceStart",
    function(resource)
        if resource ~= GetCurrentResourceName() then
            return
        end
        if not serverState.isValid then
            return
        end
        initializeCoreData()
        for _, playerId in ipairs(GetPlayers()) do
            local player = GetPlayer(playerId)
            if player then
                local gang = player.PlayerData.gang and player.PlayerData.gang.name or "CIVILIAN"
                Player(playerId).state:set("gang", gang, true)
            end
        end
    end
)

AddEventHandler(
    "onResourceStop",
    function(resource)
        if resource ~= GetCurrentResourceName() then
            return
        end
        if not serverState.isValid then
            return
        end
        for entity, _ in pairs(serverState.CoreData.Entities) do
            if DoesEntityExist(entity) then
                DeleteEntity(entity)
                serverState.CoreData:UnregisterEntity(entity)
            end
        end
    end
)

AddEventHandler(
    "playerDropped",
    function()
        if not serverState.isValid then
            return
        end
        local src = source
        local playerData = serverState.CoreData:GetPlayer(src)
        if playerData.capturingZone then
            notifyClient(src, "Territory Capture", "Operation aborted due to disconnect.", "error")
            serverState.CoreData:SetPlayerCapturing(src, nil)
            TriggerClientEvent("Enzo-GangSiegeX:syncCaptures", -1)
        end
        for entity, data in pairs(serverState.CoreData.Entities) do
            if data.type == "gangster" and data.owner == src and DoesEntityExist(entity) then
                DeleteEntity(entity)
                serverState.CoreData:UnregisterEntity(entity)
            end
        end
        if playerData then
            playerData.gangster_count = 0
            local player = GetPlayer(src)
            if player then
                MySQL.update(
                    "UPDATE siege_players SET gangster_count = 0 WHERE license = ?",
                    {player.PlayerData.license}
                )
            end
        end
    end
)

if serverState.framework == "qb" then
    AddEventHandler(
        "QBCore:Server:PlayerLoaded",
        function(player)
            if not serverState.isValid then
                return
            end
            local src = player.PlayerData.source
            local gang = player.PlayerData.gang and player.PlayerData.gang.name or "CIVILIAN"
            Player(src).state:set("gang", gang, true)
            serverState.CoreData:GetPlayer(src)
            TriggerClientEvent("Enzo-GangSiegeX:syncZones", src, serverState.CoreData.Zones)
        end
    )
elseif serverState.framework == "qbox" then
    AddEventHandler(
        "qbx_core:server:playerLoaded",
        function(src)
            if not serverState.isValid then
                return
            end
            local player = GetPlayer(src)
            local gang = player.PlayerData.gang and player.PlayerData.gang.name or "CIVILIAN"
            Player(src).state:set("gang", gang, true)
            serverState.CoreData:GetPlayer(src)
            TriggerClientEvent("Enzo-GangSiegeX:syncZones", src, serverState.CoreData.Zones)
        end
    )
end

Citizen.CreateThread(
    function()
        while true do
            Wait(300000)
            if not serverState.isValid then
                return
            end
            for zoneId, zoneData in pairs(serverState.CoreData.Zones) do
                if GlobalState["zone:" .. zoneId] ~= zoneData.gang_owner then
                    GlobalState["zone:" .. zoneId] = zoneData.gang_owner
                end
            end
        end
    end
)

Citizen.CreateThread(
    function()
        while true do
            Wait(60000)
            if not serverState.isValid then
                return
            end
            for id, expiration in pairs(serverState.CoreData.Cooldowns) do
                if expiration <= GetGameTimer() then
                    serverState.CoreData.Cooldowns[id] = nil
                    MySQL.query("DELETE FROM siege_cooldowns WHERE id = ?", {id})
                end
            end
        end
    end
)

Citizen.CreateThread(
    function()
        while true do
            Wait(10000)
            if not serverState.isValid then
                return
            end
            for _, playerId in ipairs(GetPlayers()) do
                local src = tonumber(playerId)
                local playerCoords = GetEntityCoords(GetPlayerPed(src))
                local inZone = false
                for zoneId, zoneData in pairs(serverState.CoreData.Cache.ZoneLookup) do
                    if #(playerCoords - zoneData.coords) < zoneData.radius then
                        inZone = true
                        break
                    end
                end
                if not inZone then
                    local count = 0
                    for entity, data in pairs(serverState.CoreData.Entities) do
                        if data.type == "gangster" and data.owner == src and DoesEntityExist(entity) then
                            DeleteEntity(entity)
                            serverState.CoreData:UnregisterEntity(entity)
                            count = count + 1
                        end
                    end
                    if count > 0 then
                        serverState.CoreData:SetGangsterCount(src, 0)
                        notifyClient(src, "Unit Command", "Gang units despawned", "inform")
                    end
                end
            end
        end
    end
)

Citizen.CreateThread(
    function()
        while true do
            Wait(10000)
            if not serverState.isValid then
                return
            end
            for _, playerId in ipairs(GetPlayers()) do
                local src = tonumber(playerId)
                local playerData = serverState.CoreData:GetPlayer(src)
                if playerData then -- Guard clause added here
                    local cap = playerData.capturingZone
                    if cap and cap.startTime and cap.zoneId then
                        if (GetGameTimer() - cap.startTime) / 1000 > (Config.Turf.Defaults.captureTime / 1000) + 30 then
                            serverState.CoreData:SetPlayerCapturing(src, nil)
                        end
                    end
                end
            end
        end
    end
)

Citizen.CreateThread(
    function()
        while true do
            Wait(30000)
            if not serverState.isValid then
                return
            end
            local cleaned = 0
            for entity, data in pairs(serverState.CoreData.Entities) do
                if data.type == "gangster" and (not DoesEntityExist(entity) or GetEntityHealth(entity) <= 0) then
                    serverState.CoreData:UnregisterEntity(entity)
                    if DoesEntityExist(entity) then
                        local netId = NetworkGetNetworkIdFromEntity(entity)
                        if NetworkGetEntityOwner(entity) == -1 then
                            DeleteEntity(entity)
                        end
                    end
                    cleaned = cleaned + 1
                    local ownerData = serverState.CoreData:GetPlayer(data.owner)
                    if ownerData then
                        ownerData.gangster_count = math.max(0, ownerData.gangster_count - 1)
                        MySQL.update(
                            "UPDATE siege_players SET gangster_count = ? WHERE license = ?",
                            {ownerData.gangster_count, GetPlayer(data.owner).PlayerData.license}
                        )
                    end
                end
            end
        end
    end
)

function table.count(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

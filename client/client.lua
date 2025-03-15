Config = Config or exports["Enzo-GangSiegeX"]:GetConfig()
local framework = Config.Framework:lower()
local QBCore = framework == "qb" and exports["qb-core"]:GetCoreObject() or nil
local QBX = framework == "qbox" and exports["qbx_core"] or nil

local TargetSystem = Config.TargetSystem:lower() == "qb" and "qb-target" or "ox_target"
local TargetExport = Config.TargetSystem:lower() == "qb" and exports["qb-target"] or exports["ox_target"]

local notifySystem = Config.NotifySystem:lower()

local state = {
    npc = {
        gangsters = {},
        goons = {},
        gangsterMode = "passive",
        isHostile = false,
        gangsterFollowMode = false,
        syncedPeds = {},
        goonGroups = {}
    },
    ui = {
        activeBlip = nil,
        currentDialogId = nil,
        dialogs = {}
    },
    flags = {
        hasSpawned = false,
        isCapturing = false,
        progressActive = false
    },
    zoneBlips = {},
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

state.isValid = computeStealthKey()

local function GetPlayerData()
    if not state.isValid then
        return nil
    end
    if framework == "qb" then
        return QBCore.Functions.GetPlayerData()
    elseif framework == "qbox" then
        return QBX.PlayerData or exports["qbx_core"]:GetPlayerData()
    end
    return nil
end

local function loadAnimDict(dict)
    if not state.isValid then
        return
    end
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(150)
    end
end

local function notify(title, desc, typ, duration)
    if not state.isValid then
        return
    end
    if notifySystem == "qb" and QBCore then
        QBCore.Functions.Notify(desc, typ or "info", duration or 5000)
    else
        lib.notify(
            {
                title = title,
                description = desc,
                type = typ or "inform",
                duration = duration or 5000
            }
        )
    end
end

local function setZoneBlip(zoneId, gang)
    if not state.isValid then
        return
    end
    local zone = Config.Turf.Data[zoneId]
    if not zone then
        return
    end
    if state.zoneBlips[zoneId] then
        RemoveBlip(state.zoneBlips[zoneId])
    end
    local blip = AddBlipForCoord(zone.center.x, zone.center.y, zone.center.z)
    SetBlipSprite(blip, Config.Turf.Defaults.blip.sprite or 1)
    SetBlipScale(blip, Config.Turf.Defaults.blip.scale or 1.0)
    SetBlipColour(
        blip,
        (Config.Turf.Defaults.gangster.types[gang] and Config.Turf.Defaults.gangster.types[gang].color) or
            Config.Turf.Defaults.blip.color
    )
    SetBlipAlpha(blip, Config.Turf.Defaults.blip.alpha or 255)
    SetBlipAsShortRange(blip, Config.Turf.Defaults.blip.shortRange or true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(
        (Config.Turf.Defaults.blip.showOwner and gang and (gang .. " - ") or "") ..
            (Config.Turf.Defaults.blip.name or "Territory")
    )
    EndTextCommandSetBlipName(blip)
    state.zoneBlips[zoneId] = blip
end

local function initializeZoneBlips(zones)
    if not state.isValid then
        return
    end
    for zoneId, zoneData in pairs(zones) do
        setZoneBlip(zoneId, zoneData.gang_owner)
    end
end

local function initZones()
    if not state.isValid then
        return
    end
    for zoneID, zoneData in pairs(Config.Turf.Data) do
        state.ui.dialogs[zoneID] = {
            Ped = {
                Enable = true,
                hash = "g_m_y_ballaeast_01",
                animDict = "amb@world_human_stand_guard@male@idle_a",
                animName = "idle_a",
                coords = zoneData.npc
            },
            Interaction = {
                Target = {
                    Enable = Config.Turf.Defaults.interaction.enabled,
                    Distance = Config.Turf.Defaults.interaction.distance,
                    Icon = Config.Turf.Defaults.interaction.icon,
                    Label = Config.Turf.Defaults.interaction.label
                }
            },
            AutoMessage = {Enable = true, AutoMessages = {{type = "question", text = "Greetings."}}},
            Buttons = {
                {
                    id = 1,
                    label = "Siege",
                    systemAnswer = {enable = true, type = "message", text = "Prepare for conflict."},
                    playerAnswer = {enable = true, text = "This is our turf now"},
                    maxClick = 2
                },
                {
                    id = 2,
                    label = "Intel",
                    systemAnswer = {enable = true, type = "message", text = "Hit the intel location"},
                    playerAnswer = {enable = true, text = "Ill view the details"},
                    maxClick = 2
                },
                {
                    id = 3,
                    label = "Guns",
                    systemAnswer = {enable = true, type = "message", text = "You need chops?"},
                    playerAnswer = {enable = true, text = "Show me the big shit."},
                    maxClick = 2
                },
                {
                    id = 4,
                    label = "Units",
                    systemAnswer = {enable = true, type = "message", text = "Let me make some calls."},
                    playerAnswer = {enable = true, text = "Bring the shooters."},
                    maxClick = 1
                }
            },
            Menu = {
                Label = zoneID:gsub("^%l", string.upper) .. " Operations",
                Description = "Manage " .. zoneID:gsub("^%l", string.upper),
                Icon = "fas fa-handshake"
            }
        }
    end
end

local function createDialogPed(netId, id, dialog, targetCoords)
    if not state.isValid then
        return
    end
    if not dialog.Ped.Enable then
        return
    end
    if state.npc.syncedPeds[id] then
        local ped = NetworkGetEntityFromNetworkId(state.npc.syncedPeds[id])
        if DoesEntityExist(ped) then
            return
        end
        state.npc.syncedPeds[id] = nil
    end

    local ped = NetworkGetEntityFromNetworkId(netId)
    local attempts = 0
    local maxAttempts = 50
    while not DoesEntityExist(ped) and attempts < maxAttempts do
        Wait(100)
        ped = NetworkGetEntityFromNetworkId(netId)
        attempts = attempts + 1
    end

    if not DoesEntityExist(ped) then
        notify("Error", "Failed to spawn dialog NPC.", "error")
        return
    end

    state.npc.syncedPeds[id] = netId
    SetEntityCoords(ped, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, true)
    SetEntityHeading(ped, targetCoords.w or 0.0)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    if dialog.Ped.animDict then
        loadAnimDict(dialog.Ped.animDict)
        TaskPlayAnim(ped, dialog.Ped.animDict, dialog.Ped.animName, 5.0, 5.0, -1, 1, 0, false, false, false)
    end

    if dialog.Interaction.Target.Enable and GetResourceState(TargetSystem) == "started" then
        if TargetSystem == "qb-target" then
            TargetExport:AddTargetEntity(
                ped,
                {
                    options = {
                        {
                            type = "client",
                            event = "Enzo-GangSiegeX:openDialog",
                            icon = dialog.Interaction.Target.Icon,
                            label = dialog.Interaction.Target.Label,
                            zoneId = id
                        }
                    },
                    distance = dialog.Interaction.Target.Distance
                }
            )
        else
            TargetExport:addLocalEntity(
                ped,
                {
                    {
                        name = "enzo_siege_dialog_" .. id,
                        label = dialog.Interaction.Target.Label,
                        icon = dialog.Interaction.Target.Icon,
                        distance = dialog.Interaction.Target.Distance,
                        event = "Enzo-GangSiegeX:openDialog",
                        zoneId = id
                    }
                }
            )
        end
    end
end

RegisterNetEvent(
    "Enzo-GangSiegeX:openDialog",
    function(data)
        if not state.isValid then
            return
        end
        state.ui.currentDialogId = data.zoneId
        local dialog = state.ui.dialogs[state.ui.currentDialogId]
        if not dialog then
            return
        end

        local buttonsData = {}
        for _, button in ipairs(dialog.Buttons) do
            table.insert(
                buttonsData,
                {
                    id = button.id,
                    label = button.label,
                    systemAnswer = button.systemAnswer,
                    playerAnswer = button.playerAnswer,
                    maxClick = button.maxClick
                }
            )
        end
        SendNUIMessage(
            {
                action = "openDialog",
                resourceName = GetCurrentResourceName(),
                menuData = dialog.Menu,
                buttons = buttonsData,
                autoMessages = dialog.AutoMessage.Enable and dialog.AutoMessage.AutoMessages or {}
            }
        )
        SetNuiFocus(true, true)
    end
)

local function handleDialogAction(zoneId, buttonId)
    if not state.isValid then
        return
    end
    local dialog = state.ui.dialogs[zoneId]
    if not dialog then
        return
    end

    if buttonId == 1 then
        Wait(3000)
        exports["Enzo-GangSiegeX"]:StartZoneCapture(zoneId)
        exports["Enzo-GangSiegeX"]:closeMenu()
    elseif buttonId == 2 then
        Wait(3000)
        exports["Enzo-GangSiegeX"]:toggleBlips()
        exports["Enzo-GangSiegeX"]:closeMenu()
    elseif buttonId == 3 then
        Wait(2000)
        exports["Enzo-GangSiegeX"]:OpenCraftingMenu(zoneId)
        exports["Enzo-GangSiegeX"]:closeMenu()
    elseif buttonId == 4 then
        Wait(2000)
        exports["Enzo-GangSiegeX"]:SpawnGangster()
        exports["Enzo-GangSiegeX"]:closeMenu()
    end
end

local function setupRobberyPoints()
    if not state.isValid then
        return
    end
    if GetResourceState(TargetSystem) ~= "started" then
        return
    end
    for _, point in pairs(Config.Interact.Locations.Robbery or {}) do
        if TargetSystem == "qb-target" then
            TargetExport:AddSphereZone(
                {
                    coords = point[2],
                    radius = point[3],
                    options = {
                        {
                            type = "server",
                            event = "Enzo-GangSiegeX:validateRobbery",
                            icon = "fas fa-mask",
                            label = point[4],
                            robberyName = point[1]
                        }
                    },
                    distance = 3.0
                }
            )
        else
            TargetExport:addSphereZone(
                {
                    name = point[1],
                    coords = point[2],
                    radius = point[3],
                    options = {
                        {
                            name = point[1],
                            label = point[4],
                            icon = "fas fa-mask",
                            onSelect = function()
                                local ped = PlayerPedId()
                                local pedCoords = GetEntityCoords(ped)
                                TriggerServerEvent("Enzo-GangSiegeX:validateRobbery", point[1], pedCoords)
                            end
                        }
                    }
                }
            )
        end
    end
end

exports(
    "StartZoneCapture",
    function(zoneID)
        if not state.isValid then
            return
        end
        local playerPos = GetEntityCoords(PlayerPedId())
        TriggerServerEvent("Enzo-GangSiegeX:attemptCapture", zoneID, playerPos)
    end
)

exports(
    "OpenCraftingMenu",
    function(zoneID)
        if not state.isValid then
            return
        end
        TriggerServerEvent("Enzo-GangSiegeX:validateCrafting", zoneID)
    end
)

exports(
    "toggleBlips",
    function()
        if not state.isValid then
            return
        end
        if state.ui.activeBlip then
            RemoveBlip(state.ui.activeBlip)
            state.ui.activeBlip = nil
            notify("Intelligence", "You destroyed the intel.", "inform")
            return
        end
        local blips = Config.Interact.Locations.Intel
        if not blips then
            return
        end
        local blipData = blips[math.random(#blips)]
        state.ui.activeBlip = AddBlipForCoord(blipData.coords.x, blipData.coords.y, blipData.coords.z)
        SetBlipSprite(state.ui.activeBlip, blipData.blip.id)
        SetBlipColour(state.ui.activeBlip, blipData.blip.color)
        SetBlipScale(state.ui.activeBlip, blipData.blip.size)
        SetBlipAsShortRange(state.ui.activeBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(blipData.name)
        EndTextCommandSetBlipName(state.ui.activeBlip)
        notify("Intelligence", "Intel activated.", "inform")
    end
)

exports(
    "SpawnGangster",
    function()
        if not state.isValid then
            return
        end
        local coords = GetEntityCoords(PlayerPedId())
        TriggerServerEvent("Enzo-GangSiegeX:spawnGangster", coords)
    end
)

exports(
    "RemoveGangster",
    function()
        if not state.isValid then
            return
        end
        TriggerServerEvent("Enzo-GangSiegeX:removeGangsters")
        state.npc.gangsters = {}
        state.npc.gangsterMode = "passive"
        state.npc.isHostile = false
        state.npc.gangsterFollowMode = false
        notify("Unit Command", "Gangsters withdrawn.", "inform")
    end
)

exports(
    "SetGangsterPassive",
    function()
        if not state.isValid then
            return
        end
        state.npc.gangsterMode = "passive"
        state.npc.isHostile = false
        for _, gangster in pairs(state.npc.gangsters) do
            if DoesEntityExist(gangster.ped) then
                ClearPedTasksImmediately(gangster.ped)
            end
        end
        notify("Unit Command", "Gangsters set to standby.", "inform")
    end
)

exports(
    "SetGangsterHostile",
    function(target)
        if not state.isValid or #state.npc.gangsters == 0 then
            return
        end
        local playerCoords = GetEntityCoords(PlayerPedId())
        TriggerServerEvent(
            "Enzo-GangSiegeX:validateGangsterEngage",
            playerCoords,
            target and NetworkGetNetworkIdFromEntity(target)
        )
    end
)

exports(
    "closeMenu",
    function()
        if not state.isValid then
            return
        end
        SetNuiFocus(false, false)
        SendNUIMessage({action = "closeMenu"})
    end
)

exports(
    "GetCurrentCaptureState",
    function()
        if not state.isValid then
            return false
        end
        return state.flags.isCapturing
    end
)

AddEventHandler(
    "playerSpawned",
    function()
        if not state.isValid then
            return
        end
        if state.flags.hasSpawned then
            return
        end
        local attempts = 0
        local playerData = nil
        while not playerData and attempts < 10 do
            playerData = GetPlayerData()
            Wait(500)
            attempts = attempts + 1
        end
        if not playerData then
            return
        end
        state.flags.hasSpawned = true
        local playerGang = playerData.gang and playerData.gang.name or "CIVILIAN"
        Player(PlayerId()).state:set("gang", playerGang, true)
    end
)

RegisterNetEvent(
    "Enzo-GangSiegeX:modifyGangster",
    function(netIds, playerGang)
        if not state.isValid then
            return
        end
        if source ~= 65535 then
            return
        end
        if type(netIds) ~= "table" then
            netIds = {netIds}
        end
        local weaponHash = GetHashKey(Config.Turf.Defaults.gangster.weapon)

        for _, netId in pairs(netIds) do
            local gangster = NetworkGetEntityFromNetworkId(netId)
            local attempts = 0
            local maxAttempts = 30
            while not DoesEntityExist(gangster) and attempts < maxAttempts do
                Wait(200)
                gangster = NetworkGetEntityFromNetworkId(netId)
                attempts = attempts + 1
            end

            if not DoesEntityExist(gangster) then
                notify("Unit Error", "Failed to initialize gangster unit.", "error")
                goto continue
            end

            if Entity(gangster).state.owner ~= GetPlayerServerId(PlayerId()) then
                goto continue
            end

            NetworkRequestControlOfEntity(gangster)
            local controlAttempts = 0
            while not NetworkHasControlOfEntity(gangster) and controlAttempts < 5 do
                NetworkRequestControlOfEntity(gangster)
                Wait(100)
                controlAttempts = controlAttempts + 1
            end

            if not NetworkHasControlOfEntity(gangster) then
                notify("Unit Error", "Failed to gain control of gangster unit.", "error")
                goto continue
            end

            SetEntityAsMissionEntity(gangster, true, true)
            SetPedCanRagdoll(gangster, false)
            SetBlockingOfNonTemporaryEvents(gangster, true)
            SetPedFleeAttributes(gangster, 0, false)
            SetPedCombatAttributes(gangster, 46, true)
            if Config.Turf.Defaults.gangster.armGangsters then
                GiveWeaponToPed(gangster, weaponHash, 100, false, true)
                SetCurrentPedWeapon(gangster, weaponHash, true)
                SetPedInfiniteAmmo(gangster, true, weaponHash)
            end

            local exists = false
            for i, g in pairs(state.npc.gangsters) do
                if g.netId == netId then
                    exists = true
                    state.npc.gangsters[i] = {ped = gangster, netId = netId}
                    break
                end
            end
            if not exists then
                table.insert(state.npc.gangsters, {ped = gangster, netId = netId})
            end

            ::continue::
        end
        if #state.npc.gangsters > 0 then
            notify("Unit Command", "Gangster deployed.", "inform")
        end
    end
)

local function engageTargetThread(ped, zoneId, controllingGang, initialTarget, duration, weaponHash, isGoon)
    if not state.isValid or not DoesEntityExist(ped) or GetEntityHealth(ped) <= 0 then
        return
    end
    local zoneCoords = Config.Turf.Data[zoneId].center
    local endTime = duration and GetGameTimer() + duration or nil
    local currentTarget = initialTarget
    local groupHash = isGoon and GetHashKey("GOON_" .. zoneId) or GetHashKey("GANGSTER_" .. controllingGang)

    if Config.Turf.Defaults.gangster.armGangsters then
        local weapon = weaponHash or GetHashKey(Config.Turf.Defaults.gangster.weapon)
        GiveWeaponToPed(ped, weapon, 9999, false, true)
        SetCurrentPedWeapon(ped, weapon, true)
        SetPedInfiniteAmmo(ped, true, weapon)
        SetPedAccuracy(ped, 75)
        SetPedCombatAttributes(ped, 46, true)
        SetPedCombatAttributes(ped, 5, true)
        SetPedCombatRange(ped, 2)
        SetPedCombatMovement(ped, 2)
        SetPedCombatAbility(ped, 100)
    end

    SetPedRelationshipGroupHash(ped, groupHash)
    SetRelationshipBetweenGroups(0, groupHash, groupHash)
    SetRelationshipBetweenGroups(5, groupHash, GetHashKey("PLAYER"))
    SetPedSeeingRange(ped, 50.0)
    SetPedHearingRange(ped, 50.0)

    ClearPedTasksImmediately(ped)

    Citizen.CreateThread(
        function()
            while DoesEntityExist(ped) and GetEntityHealth(ped) > 0 and (not endTime or GetGameTimer() < endTime) do
                Wait(500)

                if
                    not currentTarget or not DoesEntityExist(currentTarget) or IsEntityDead(currentTarget) or
                        not IsPedAPlayer(currentTarget)
                 then
                    currentTarget = nil
                    local foundTarget = nil
                    for _, pid in pairs(GetActivePlayers()) do
                        local targetPed = GetPlayerPed(pid)
                        if DoesEntityExist(targetPed) and GetEntityHealth(targetPed) > 0 and IsPedAPlayer(targetPed) then
                            local targetCoords = GetEntityCoords(targetPed)
                            if #(targetCoords - zoneCoords) <= Config.Turf.Defaults.radius then
                                local targetServerId = GetPlayerServerId(pid)
                                local targetGang = Player(targetServerId).state.gang or "CIVILIAN"
                                if targetGang ~= controllingGang then
                                    foundTarget = targetPed
                                    break
                                end
                            end
                        end
                    end
                    if foundTarget then
                        currentTarget = foundTarget
                        ClearPedTasksImmediately(ped)
                        TaskCombatPed(ped, currentTarget, 0, 16)
                        SetCurrentPedWeapon(ped, weaponHash or GetHashKey(Config.Turf.Defaults.gangster.weapon), true)
                    end
                end

                if currentTarget and DoesEntityExist(currentTarget) and GetEntityHealth(currentTarget) > 0 then
                    if GetSelectedPedWeapon(ped) ~= (weaponHash or GetHashKey(Config.Turf.Defaults.gangster.weapon)) then
                        SetCurrentPedWeapon(ped, weaponHash or GetHashKey(Config.Turf.Defaults.gangster.weapon), true)
                    end
                    if not IsPedInCombat(ped, currentTarget) then
                        TaskCombatPed(ped, currentTarget, 0, 16)
                    end
                elseif not currentTarget then
                    TaskWanderInArea(
                        ped,
                        zoneCoords.x,
                        zoneCoords.y,
                        zoneCoords.z,
                        Config.Turf.Defaults.radius,
                        1.0,
                        1.0
                    )
                end
                Wait(500)
            end

            if DoesEntityExist(ped) and GetEntityHealth(ped) > 0 then
                ClearPedTasks(ped)
                if not isGoon then
                    if not currentTarget then
                        state.npc.gangsterMode = "passive"
                        state.npc.isHostile = false
                    end
                else
                    Wait(5000)
                    if NetworkHasControlOfEntity(ped) then
                        local netId = NetworkGetNetworkIdFromEntity(ped)
                        DeleteEntity(ped)
                        TriggerServerEvent("Enzo-GangSiegeX:unregisterGoon", netId)
                    end
                end
            end
        end
    )
end

RegisterNetEvent(
    "Enzo-GangSiegeX:spawnGoon",
    function(goonNetIds, zoneId, controllingGang, attackerSrc)
        if not state.isValid then
            return
        end
        local attackerPed = GetPlayerPed(GetPlayerFromServerId(attackerSrc))
        local waveConfig = Config.Turf.Data[zoneId].waves or Config.Turf.Defaults.waves
        local weaponHash = GetHashKey(waveConfig.weapon or Config.Turf.Defaults.waves.weapon)
        local gangGroup = GetHashKey(controllingGang:upper())

        AddRelationshipGroup(controllingGang:upper())
        SetRelationshipBetweenGroups(0, gangGroup, gangGroup)

        for _, netId in ipairs(goonNetIds) do
            local attempts = 0
            local maxAttempts = 10
            local goonPed = nil

            while not NetworkDoesEntityExistWithNetworkId(netId) and attempts < maxAttempts do
                Wait(100)
                attempts = attempts + 1
            end

            if NetworkDoesEntityExistWithNetworkId(netId) then
                goonPed = NetworkGetEntityFromNetworkId(netId)
                if DoesEntityExist(goonPed) then
                    if not NetworkHasControlOfEntity(goonPed) then
                        NetworkRequestControlOfEntity(goonPed)
                        local controlAttempts = 0
                        while not NetworkHasControlOfEntity(goonPed) and controlAttempts < 5 do
                            Wait(100)
                            controlAttempts = controlAttempts + 1
                        end
                    end

                    if not HasPedGotWeapon(goonPed, weaponHash, false) then
                        GiveWeaponToPed(goonPed, weaponHash, 999, false, true)
                    end
                    SetCurrentPedWeapon(goonPed, weaponHash, true)
                    SetPedAmmo(goonPed, weaponHash, 999)
                    SetPedDropsWeaponsWhenDead(goonPed, false)
                    SetPedInfiniteAmmo(goonPed, true, weaponHash)

                    SetPedAsEnemy(goonPed, true)
                    SetPedRelationshipGroupHash(goonPed, gangGroup)
                    SetPedCombatAttributes(goonPed, 46, true)
                    SetPedCombatAttributes(goonPed, 5, false)
                    SetPedCombatAttributes(goonPed, 2, false)
                    SetPedCombatAttributes(goonPed, 0, true)
                    SetPedCombatMovement(goonPed, 2)
                    SetPedCombatRange(goonPed, 2)
                    SetPedFleeAttributes(goonPed, 0, false)
                    SetPedAccuracy(goonPed, 50)
                    SetPedSeeingRange(goonPed, 50.0)
                    SetPedHearingRange(goonPed, 50.0)

                    Citizen.CreateThread(
                        function()
                            local timeout = GetGameTimer() + 60000
                            local currentTarget = attackerPed
                            local zoneCenter = Config.Turf.Data[zoneId].center
                            local radius = Config.Turf.Defaults.radius or 50.0
                            local wanderStart = nil
                            local lastDeadTarget = nil

                            if currentTarget and DoesEntityExist(currentTarget) then
                                local targetServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(currentTarget))
                                local targetState = targetServerId and Player(targetServerId).state or {}
                                local isDeadOrDowned =
                                    IsEntityDead(currentTarget) or targetState.isDead or
                                    (GetEntityHealth(currentTarget) <= 0)
                                if not isDeadOrDowned then
                                    TaskCombatPed(goonPed, currentTarget, 0, 16)
                                else
                                    lastDeadTarget = currentTarget
                                end
                            end

                            while DoesEntityExist(goonPed) and GetEntityHealth(goonPed) > 0 and GetGameTimer() < timeout do
                                Wait(500)

                                if GetSelectedPedWeapon(goonPed) ~= weaponHash then
                                    SetCurrentPedWeapon(goonPed, weaponHash, true)
                                end

                                if currentTarget and DoesEntityExist(currentTarget) then
                                    local targetServerId =
                                        GetPlayerServerId(NetworkGetPlayerIndexFromPed(currentTarget))
                                    local targetState = targetServerId and Player(targetServerId).state or {}
                                    local isDeadOrDowned =
                                        IsEntityDead(currentTarget) or targetState.isDead or
                                        (GetEntityHealth(currentTarget) <= 0)
                                    if isDeadOrDowned then
                                        ClearPedTasks(goonPed)
                                        lastDeadTarget = currentTarget
                                        currentTarget = nil
                                    end
                                elseif not currentTarget then
                                    currentTarget = nil
                                end

                                if not currentTarget then
                                    local players = GetActivePlayers()
                                    for _, pid in pairs(players) do
                                        local ped = GetPlayerPed(pid)
                                        if DoesEntityExist(ped) and ped ~= lastDeadTarget then
                                            local pedServerId = GetPlayerServerId(pid)
                                            local pedState = Player(pedServerId).state or {}
                                            local isDeadOrDowned =
                                                IsEntityDead(ped) or pedState.isDead or (GetEntityHealth(ped) <= 0)
                                            if not isDeadOrDowned then
                                                local pedCoords = GetEntityCoords(ped)
                                                if #(pedCoords - GetEntityCoords(goonPed)) < radius then
                                                    local targetGang = pedState.gang or "CIVILIAN"
                                                    if targetGang ~= controllingGang then
                                                        currentTarget = ped
                                                        TaskCombatPed(goonPed, currentTarget, 0, 16)
                                                        wanderStart = nil
                                                        break
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end

                                if not currentTarget then
                                    if not wanderStart then
                                        TaskWanderInArea(
                                            goonPed,
                                            zoneCenter.x,
                                            zoneCenter.y,
                                            zoneCenter.z,
                                            radius,
                                            1.0,
                                            1.0
                                        )
                                        wanderStart = GetGameTimer()
                                    elseif (GetGameTimer() - wanderStart) >= 10000 then
                                        local hasHostiles = false
                                        local players = GetActivePlayers()
                                        for _, pid in pairs(players) do
                                            local ped = GetPlayerPed(pid)
                                            if DoesEntityExist(ped) and ped ~= lastDeadTarget then
                                                local pedServerId = GetPlayerServerId(pid)
                                                local pedState = Player(pedServerId).state or {}
                                                local isDeadOrDowned =
                                                    IsEntityDead(ped) or pedState.isDead or (GetEntityHealth(ped) <= 0)
                                                if not isDeadOrDowned then
                                                    local pedCoords = GetEntityCoords(ped)
                                                    if #(pedCoords - zoneCenter) < radius then
                                                        local targetGang = pedState.gang or "CIVILIAN"
                                                        if targetGang ~= controllingGang then
                                                            hasHostiles = true
                                                            break
                                                        end
                                                    end
                                                end
                                            end
                                        end

                                        if not hasHostiles then
                                            break
                                        end
                                    end
                                end
                            end

                            if DoesEntityExist(goonPed) and NetworkHasControlOfEntity(goonPed) then
                                DeleteEntity(goonPed)
                                TriggerServerEvent("Enzo-GangSiegeX:unregisterGoon", netId)
                            end
                        end
                    )
                end
            end
        end
    end
)

RegisterNetEvent(
    "Enzo-GangSiegeX:engageGangsters",
    function(zoneId, controllingGang, targetNetId)
        if not state.isValid then
            return
        end
        local target = targetNetId and NetworkGetEntityFromNetworkId(targetNetId) or nil
        local weaponHash = GetHashKey(Config.Turf.Defaults.gangster.weapon)
        state.npc.gangsterMode = "hostile"
        state.npc.isHostile = true

        if #state.npc.gangsters == 0 then
            notify("Unit Command", "No gang units available to engage.", "error")
            return
        end

        for _, gangster in pairs(state.npc.gangsters) do
            if DoesEntityExist(gangster.ped) and GetEntityHealth(gangster.ped) > 0 then
                engageTargetThread(gangster.ped, zoneId, controllingGang, target, 10000, weaponHash, false)
            end
        end
        notify("Unit Command", "Gangsters engaging targets for 10 seconds.", "inform")
    end
)

RegisterNetEvent(
    "Enzo-GangSiegeX:notify",
    function(typ, desc, title, duration)
        if not state.isValid then
            return
        end
        if source ~= 65535 then
            return
        end
        notify(title or "Notification", desc, typ, duration)
    end
)

RegisterNetEvent(
    "Enzo-GangSiegeX:syncZones",
    function(zones)
        if not state.isValid then
            return
        end
        if source ~= 65535 then
            return
        end
        initializeZoneBlips(zones)
    end
)

RegisterNetEvent(
    "Enzo-GangSiegeX:syncDialogPed",
    function(netId, id, targetCoords)
        if not state.isValid then
            return
        end
        if source ~= 65535 then
            return
        end

        local playerCoords = GetEntityCoords(PlayerPedId())
        local distance = #(playerCoords - vector3(targetCoords.x, targetCoords.y, targetCoords.z))

        -- Only create ped if within 500 units
        if distance < 500 then
            local dialog = state.ui.dialogs[id]
            if dialog then
                createDialogPed(netId, id, dialog, targetCoords)
            end
        end
    end
)

Citizen.CreateThread(
    function()
        while true do
            Wait(5000)
            if not state.isValid then
                return
            end
            local playerCoords = GetEntityCoords(PlayerPedId())
            for zoneId, zoneData in pairs(Config.Turf.Data) do
                local distance = #(playerCoords - zoneData.center)
                local netId = state.npc.syncedPeds[zoneId]
                local ped = netId and NetworkGetEntityFromNetworkId(netId)

                if distance < 500 then
                    if not ped or not DoesEntityExist(ped) then
                        TriggerServerEvent("Enzo-GangSiegeX:requestDialogPed", zoneId, playerCoords)
                    end
                elseif netId and (not ped or not DoesEntityExist(ped)) then
                    state.npc.syncedPeds[zoneId] = nil
                end
            end
        end
    end
)

RegisterNetEvent(
    "Enzo-GangSiegeX:playInteractionAnimation",
    function(point)
        if not state.isValid then
            return
        end
        if source ~= 65535 then
            return
        end
        local ped = PlayerPedId()
        local animDict = point[5] or "amb@world_human_stand_impatient@male@no_sign@idle_a"
        local animName = point[6] or "idle_a"
        local duration = point[7] or 5000
        loadAnimDict(animDict)
        TaskPlayAnim(ped, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)
        local success =
            lib.progressBar(
            {
                duration = duration,
                label = "Executing operation...",
                useWhileDead = false,
                canCancel = false,
                disable = {move = true, combat = true},
                anim = {dict = animDict, clip = animName, flag = 1}
            }
        )
        ClearPedTasks(ped)
        if success then
            TriggerServerEvent("Enzo-GangSiegeX:attemptReward", point[1])
        else
            notify("Operation", "Robbery interrupted.", "error")
        end
    end
)

RegisterNetEvent(
    "Enzo-GangSiegeX:receiveRobberyReward",
    function(rewards, xp, level)
        if not state.isValid then
            return
        end
        if source ~= 65535 then
            return
        end
        local rewardText = ""
        for _, reward in pairs(rewards) do
            rewardText = rewardText .. reward.item .. " (" .. reward.chance .. "%) "
        end
        local desc = string.format("Found: %s | XP: %d | Level: %d", rewardText, xp, level)
        notify("Operation", desc, "success", 7000)
    end
)

RegisterNetEvent(
    "Enzo-GangSiegeX:openCrafting",
    function(zoneId)
        if not state.isValid then
            return
        end
        if source ~= 65535 then
            return
        end
        if not Config.Crafting.enabled then
            notify("Crafting", "Crafting is disabled.", "error")
            return
        end

        if Config.Crafting.system == "cw" and exports["cw-crafting"] then
            exports["cw-crafting"]:setCraftingOpen(true, Config.Crafting.table)
        elseif Config.Crafting.system == "ox" and exports.ox_inventory then
            lib.registerContext(
                {
                    id = "crafting_menu_" .. zoneId,
                    title = zoneId:gsub("^%l", string.upper) .. " Crafting",
                    options = (function()
                        local options = {}
                        for i, recipe in ipairs(Config.Crafting.recipes) do
                            local requirements =
                                table.concat(
                                (function()
                                    local reqs = {}
                                    for _, input in pairs(recipe.inputs) do
                                        table.insert(reqs, input.amount .. "x " .. input.item)
                                    end
                                    return reqs
                                end)(),
                                ", "
                            )
                            table.insert(
                                options,
                                {
                                    title = "Craft " .. recipe.output,
                                    description = "Requires: " ..
                                        requirements .. " | Time: " .. (recipe.duration / 1000) .. "s",
                                    onSelect = function()
                                        if
                                            lib.progressBar(
                                                {
                                                    duration = recipe.duration,
                                                    label = "Crafting " .. recipe.output .. "...",
                                                    useWhileDead = false,
                                                    canCancel = false,
                                                    disable = {combat = true}
                                                }
                                            )
                                         then
                                            TriggerServerEvent("Enzo-GangSiegeX:craftItem", zoneId, i)
                                        end
                                    end
                                }
                            )
                        end
                        return options
                    end)()
                }
            )
            lib.showContext("crafting_menu_" .. zoneId)
        else
            notify("Crafting", "No valid crafting system detected.", "error")
        end
    end
)

RegisterNetEvent(
    "Enzo-GangSiegeX:startCapture",
    function(zoneId)
        if not state.isValid then
            return
        end
        if source ~= 65535 then
            return
        end
        state.flags.isCapturing = true
        state.flags.progressActive = true
        local success =
            lib.progressBar(
            {
                duration = Config.Turf.Defaults.captureTime,
                label = "Sieging Turf...",
                useWhileDead = false,
                canCancel = false,
                disable = {combat = true}
            }
        )
        state.flags.progressActive = false
        if success then
            state.flags.isCapturing = false
            notify("Turf Capture", "Capture completed!", "success")
        end
    end
)

RegisterNetEvent(
    "Enzo-GangSiegeX:abortCapture",
    function(zoneId)
        if not state.isValid then
            return
        end
        if source ~= 65535 then
            return
        end
        if state.flags.progressActive then
            local success, err =
                pcall(
                function()
                    lib.cancelProgress()
                end
            )
            if not success then
                print("Failed to cancel progress: " .. tostring(err))
            end
        end
        state.flags.isCapturing = false
    end
)

RegisterNetEvent(
    "Enzo-GangSiegeX:syncCaptures",
    function()
        if not state.isValid then
            return
        end
        if source ~= 65535 then
            return
        end
    end
)

AddEventHandler(
    "onClientResourceStart",
    function(resource)
        if resource ~= GetCurrentResourceName() then
            return
        end
        if not state.isValid then
            return
        end
        initZones()
        setupRobberyPoints()
        TriggerServerEvent("Enzo-GangSiegeX:requestZones")
    end
)

AddEventHandler(
    "onClientResourceStop",
    function(resource)
        if resource ~= GetCurrentResourceName() then
            return
        end
        if not state.isValid then
            return
        end
        for _, goonGroup in pairs(state.npc.goons) do
            for _, goon in pairs(goonGroup) do
                if DoesEntityExist(goon) and NetworkHasControlOfEntity(goon) then
                    DeleteEntity(goon)
                end
            end
        end
        for _, gangster in pairs(state.npc.gangsters) do
            if DoesEntityExist(gangster.ped) and NetworkHasControlOfEntity(gangster.ped) then
                DeleteEntity(gangster.ped)
            end
        end
        TriggerServerEvent("Enzo-GangSiegeX:removeGangsters")
        state.npc.gangsters = {}
        state.npc.gangsterMode = "passive"
        state.npc.isHostile = false
        state.npc.gangsterFollowMode = false
        for _, blip in pairs(state.zoneBlips) do
            if DoesBlipExist(blip) then
                RemoveBlip(blip)
            end
        end
        if state.ui.activeBlip and DoesBlipExist(state.ui.activeBlip) then
            RemoveBlip(state.ui.activeBlip)
        end
        state.npc.syncedPeds = {}
        state.flags.isCapturing = false
    end
)

RegisterNUICallback(
    "callback",
    function(data)
        if not state.isValid then
            return
        end
        if data.action == "nuiFocus" then
            exports["Enzo-GangSiegeX"]:closeMenu()
        elseif data.action == "onClick" then
            if state.ui.currentDialogId and data.id then
                handleDialogAction(state.ui.currentDialogId, data.id)
            end
        end
    end
)

local function OpenGangsterMenu()
    if not state.isValid then
        return
    end
    local isShiftHeld = IsControlPressed(0, 21)
    local targetMode = isShiftHeld and "Nearest Aimed Unit" or "All Units"
    local description = "Hold SHIFT to target the Gang unit nearest your aim. Mode: " .. targetMode

    local function getTargetGangster()
        if not isShiftHeld then
            local validGangsters = {}
            for _, gangster in pairs(state.npc.gangsters) do
                if DoesEntityExist(gangster.ped) and GetEntityHealth(gangster.ped) > 0 then
                    table.insert(validGangsters, gangster)
                end
            end
            return validGangsters
        end
        local playerPed = PlayerPedId()
        local camCoords = GetGameplayCamCoord()
        local camRot = GetGameplayCamRot(2)
        local camForward =
            vector3(
            -math.sin(math.rad(camRot.z)) * math.cos(math.rad(camRot.x)),
            math.cos(math.rad(camRot.z)) * math.cos(math.rad(camRot.x)),
            math.sin(math.rad(camRot.x))
        )
        local rayEnd = camCoords + camForward * 100.0
        local rayHandle =
            StartShapeTestLosProbe(
            camCoords.x,
            camCoords.y,
            camCoords.z,
            rayEnd.x,
            rayEnd.y,
            rayEnd.z,
            12,
            playerPed,
            0
        )
        local _, hit, _, _, entityHit = GetShapeTestResult(rayHandle)
        if hit and DoesEntityExist(entityHit) then
            for _, gangster in pairs(state.npc.gangsters) do
                if gangster.ped == entityHit and GetEntityHealth(gangster.ped) > 0 then
                    return {gangster}
                end
            end
        end
        local nearestGangster = nil
        local minAngle = math.huge
        local playerCoords = GetEntityCoords(playerPed)
        for _, gangster in pairs(state.npc.gangsters) do
            if DoesEntityExist(gangster.ped) and GetEntityHealth(gangster.ped) > 0 then
                local gangsterCoords = GetEntityCoords(gangster.ped)
                local directionToGangster = gangsterCoords - playerCoords
                local angle =
                    math.deg(
                    math.acos(
                        (directionToGangster.x * camForward.x + directionToGangster.y * camForward.y +
                            directionToGangster.z * camForward.z) /
                            (#directionToGangster * #camForward)
                    )
                )
                if angle < minAngle and angle < 30.0 then
                    minAngle = angle
                    nearestGangster = gangster
                end
            end
        end
        return nearestGangster and {nearestGangster} or {}
    end

    local function getNearestEnemy()
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local nearestEnemy = nil
        local minDistance = math.huge
        for _, pid in pairs(GetActivePlayers()) do
            local targetPed = GetPlayerPed(pid)
            if DoesEntityExist(targetPed) and targetPed ~= playerPed and GetEntityHealth(targetPed) > 0 then
                local targetCoords = GetEntityCoords(targetPed)
                local distance = #(playerCoords - targetCoords)
                if distance < minDistance and distance < 50.0 then
                    minDistance = distance
                    nearestEnemy = targetPed
                end
            end
        end
        return nearestEnemy
    end

    local activeGangsters = getTargetGangster()
    lib.registerContext(
        {
            id = "Gangster_menu",
            title = "Unit Command Center",
            description = description .. " | Active Units: " .. #activeGangsters,
            options = {
                {
                    title = "Disengage",
                    icon = "hand-peace",
                    onSelect = function()
                        if #activeGangsters == 0 then
                            notify("Unit Command", "No active gang units to command.", "error")
                            return
                        end
                        for _, gangster in pairs(activeGangsters) do
                            if DoesEntityExist(gangster.ped) then
                                ClearPedTasksImmediately(gangster.ped)
                            end
                        end
                        state.npc.gangsterMode = "passive"
                        state.npc.isHostile = false
                        state.npc.gangsterFollowMode = false
                        notify("Unit Command", "Gangsters set to Disengage.", "inform")
                    end
                },
                {
                    title = "Engage",
                    icon = "skull-crossbones",
                    onSelect = function()
                        if #activeGangsters == 0 then
                            notify("Unit Command", "No enemy gang units to engage.", "error")
                            return
                        end
                        local nearestEnemy = getNearestEnemy()
                        local playerCoords = GetEntityCoords(PlayerPedId())
                        TriggerServerEvent(
                            "Enzo-GangSiegeX:validateGangsterEngage",
                            playerCoords,
                            nearestEnemy and NetworkGetNetworkIdFromEntity(nearestEnemy)
                        )
                    end
                },
                {
                    title = "Here",
                    icon = "location-arrow",
                    onSelect = function()
                        local coords = GetEntityCoords(PlayerPedId())
                        if #activeGangsters == 0 then
                            notify("Unit Command", "No active gang units to relocate.", "error")
                            return
                        end
                        for _, gangster in pairs(activeGangsters) do
                            if DoesEntityExist(gangster.ped) then
                                TaskGoToCoordAnyMeans(
                                    gangster.ped,
                                    coords.x,
                                    coords.y,
                                    coords.z,
                                    1.0,
                                    0,
                                    0,
                                    786603,
                                    0xbf800000
                                )
                                TriggerServerEvent(
                                    "Enzo-GangSiegeX:syncGangsterPosition",
                                    NetworkGetNetworkIdFromEntity(gangster.ped),
                                    coords
                                )
                            end
                        end
                        state.npc.gangsterFollowMode = false
                        notify("Unit Command", "Gangsters relocating.", "inform")
                    end
                },
                {
                    title = "Escort",
                    icon = "walking",
                    onSelect = function()
                        if #activeGangsters == 0 then
                            notify("Unit Command", "No active gang units to escort.", "error")
                            return
                        end
                        state.npc.gangsterFollowMode = not state.npc.gangsterFollowMode
                        if state.npc.gangsterFollowMode then
                            local playerPed = PlayerPedId()
                            local offsets = {
                                {x = -1.0, y = -1.0},
                                {x = 1.0, y = -1.0},
                                {x = -2.0, y = -2.0},
                                {x = 2.0, y = -2.0}
                            }
                            local gangsterCount = 0
                            for _, gangster in pairs(activeGangsters) do
                                if DoesEntityExist(gangster.ped) then
                                    gangsterCount = gangsterCount + 1
                                    local offset = offsets[gangsterCount] or {x = 0.0, y = -1.0}
                                    TaskFollowToOffsetOfEntity(
                                        gangster.ped,
                                        playerPed,
                                        offset.x,
                                        offset.y,
                                        0.0,
                                        1.0,
                                        -1,
                                        1.0,
                                        true
                                    )
                                    TriggerServerEvent(
                                        "Enzo-GangSiegeX:syncGangsterFollow",
                                        NetworkGetNetworkIdFromEntity(gangster.ped),
                                        offset.x,
                                        offset.y
                                    )
                                end
                            end
                            notify("Unit Command", "Units now escorting.", "inform")
                        else
                            for _, gangster in pairs(activeGangsters) do
                                if DoesEntityExist(gangster.ped) then
                                    ClearPedTasksImmediately(gangster.ped)
                                    TriggerServerEvent(
                                        "Enzo-GangSiegeX:syncGangsterPosition",
                                        NetworkGetNetworkIdFromEntity(gangster.ped),
                                        GetEntityCoords(gangster.ped)
                                    )
                                end
                            end
                            notify("Unit Command", "Escort mode deactivated.", "inform")
                        end
                    end
                }
            }
        }
    )
    lib.showContext("Gangster_menu")
end

RegisterKeyMapping("Gangstermenu", "Unit Command Menu", "keyboard", Config.Turf.Defaults.gangster.menuKey or "G")
RegisterCommand("Gangstermenu", OpenGangsterMenu, false)

RegisterNetEvent(
    "Enzo-GangSiegeX:updateGangsterPosition",
    function(netId, coords)
        if not state.isValid then
            return
        end
        if source ~= 65535 then
            return
        end
        local gangster = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(gangster) and not NetworkHasControlOfEntity(gangster) then
            TaskGoToCoordAnyMeans(gangster, coords.x, coords.y, coords.z, 1.0, 0, 0, 786603, 0xbf800000)
        end
    end
)

RegisterNetEvent(
    "Enzo-GangSiegeX:updateGangsterFollow",
    function(netId, offsetX, offsetY)
        if not state.isValid then
            return
        end
        if source ~= 65535 then
            return
        end
        local gangster = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(gangster) and not NetworkHasControlOfEntity(gangster) then
            TaskFollowToOffsetOfEntity(gangster, PlayerPedId(), offsetX, offsetY, 0.0, 1.0, -1, 1.0, true)
        end
    end
)

Citizen.CreateThread(
    function()
        while true do
            Wait(5000)
            if not state.isValid then
                return
            end
            if #state.npc.gangsters == 0 then
                goto continue
            end
            local playerCoords = GetEntityCoords(PlayerPedId())
            local inZone = false
            for zoneId, zoneData in pairs(Config.Turf.Data) do
                if #(playerCoords - zoneData.center) < (Config.Turf.Defaults.radius or 50) then
                    inZone = true
                    break
                end
            end

            for i = #state.npc.gangsters, 1, -1 do
                local gangster = state.npc.gangsters[i]
                if not gangster or not DoesEntityExist(gangster.ped) or GetEntityHealth(gangster.ped) <= 0 then
                    table.remove(state.npc.gangsters, i)
                elseif not inZone and NetworkHasControlOfEntity(gangster.ped) then
                    DeleteEntity(gangster.ped)
                    table.remove(state.npc.gangsters, i)
                    notify("Unit Command", "Gang units despawned", "inform")
                    TriggerServerEvent("Enzo-GangSiegeX:removeGangsters")
                end
            end

            if #state.npc.gangsters == 0 then
                TriggerServerEvent("Enzo-GangSiegeX:removeGangsters")
            end

            ::continue::
        end
    end
)

Citizen.CreateThread(
    function()
        while true do
            Wait(1000)
            if not state.isValid then
                return
            end
            local playerPed = PlayerPedId()
            if IsEntityDead(playerPed) then
                if state.flags.isCapturing then
                    TriggerServerEvent("Enzo-GangSiegeX:abortCaptureDueToDeath")
                end
            end
        end
    end
)

AddStateBagChangeHandler(
    "capturingZone",
    ("player:%d"):format(GetPlayerServerId(PlayerId())),
    function(bagName, key, value)
        if not state.isValid then
            return
        end
        state.flags.isCapturing = value == true
    end
)

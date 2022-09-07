local self = {}

self.MaxPlayers = GetConvarInt("sv_maxclients", 30)
self.DisplayQueue = GetConvar("sv_displayqueue", "true") == "true" and true or false
self.InitHostName = GetConvar("sv_hostname")

self.ServerName = nil
self.QueueList = {}
self.PlayerList = {}
self.PlayerCount = 0
self.Priority = {}
self.Connecting = {}
self.JoinCbs = {}
self.TempPriority = {}
self.JoinDelay = GetGameTimer() + serverConfig.queue_join_delay and serverConfig.queue_join_delay or 0
self.resourcesLoaded = false

local tostring = tostring
local tonumber = tonumber
local ipairs = ipairs
local pairs = pairs
local print = print
local string_len = string.len
local string_sub = string.sub
local string_format = string.format
local string_lower = string.lower
local math_abs = math.abs
local math_floor = math.floor
local math_random = math.random
local os_time = os.time
local table_insert = table.insert
local table_remove = table.remove

local function AdaptiveCard(deferrals, title, text)
    deferrals.presentCard([==[
        {
            "type": "AdaptiveCard",
            "backgroundImage": {
                "url": "]==] .. serverConfig.adaptive_card.background_image .. [==["
            },
            "body": [
                {
                    "type": "Image",
                    "url": "]==] .. serverConfig.adaptive_card.icon_center .. [==[",
                    "size": "Small",
                    "horizontalAlignment": "Center"
                },
                {
                    "type": "TextBlock",
                    "text": "]==] .. title .. [==[",
                    "wrap": true,
                    "size": "Large",
                    "weight": "Bolder",
                    "horizontalAlignment":"Center"
                },
                {
                    "type": "TextBlock",
                    "text": "]==] .. text .. [==[",
                    "wrap": true,
                    "size": "Medium",
                    "horizontalAlignment":"Center"
                },
                {
                    "type": "ColumnSet",
                    "columns": [
                        {
                            "type": "Column",
                            "width": "stretch",
                            "items": [
                                {
                                    "type": "ActionSet",
                                    "actions": [
                                        {
                                            "type": "Action.OpenUrl",
                                            "title": "]==] .. serverConfig.adaptive_card.column.button_1.title .. [==[",
                                            "url": "]==] .. serverConfig.adaptive_card.column.button_1.url .. [==["
                                        }
                                    ]
                                }
                            ]
                        },
                        {
                            "type": "Column",
                            "width": "stretch",
                            "items": [
                                {
                                    "type": "ActionSet",
                                    "actions": [
                                        {
                                            "type": "Action.OpenUrl",
                                            "title": "]==] .. serverConfig.adaptive_card.column.button_2.title .. [==[",
                                            "url": "]==] .. serverConfig.adaptive_card.column.button_2.url .. [==["
                                        }
                                    ]
                                }
                            ]
                        }
                    ],
                    "spacing": "Large"
                }
            ],
            "actions": [
                {
                    "type": "Action.OpenUrl",
                    "title": "]==] .. serverConfig.adaptive_card.action.title .. [==[",
                    "url": "]==] .. serverConfig.adaptive_card.action.url .. [==["
                }
            ],
            "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
            "version": "1.3"
        }
    ]==])
end

self.InitHostName = self.InitHostName ~= "NKCore on Top" and self.InitHostName or false

for id, power in pairs(serverConfig.priority) do
    self.Priority[string_lower(id)] = power
end

local function IsSteamRunning(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if string_sub(id, 1, 5) == "steam" then
            return true
        end
    end
    
    return false
end

local function ConvertHexToId(data)
    local cid = math_floor(tonumber(string_sub(data, 7), 16))
	local steam64 = math_floor(tonumber(string_sub( cid, 2)))
	local alu = steam64 % 2 == 0 and 0 or 1
	local iu = math_floor(math_abs(6561197960265728 - steam64 - alu) / 2)
	local id = "steam_0:"..alu..":"..(alu == 1 and iu -1 or iu)

    return id
end

local function StillInQueue(ids, rtnTbl, bySource, connecting)
    local connList = self.Connecting
    local queueList = self.QueueList

    for genericKey1, genericValue1 in ipairs(connecting and connList or queueList) do
        local inQueue = false

        if not bySource then
            for genericKey2, genericValue2 in ipairs(genericValue1.ids) do
                if inQueue then
                    break
                end

                for genericKey3, genericValue3 in ipairs(ids) do
                    if genericValue3 == genericValue2 then
                        inQueue = true
                        break
                    end
                end
            end
        else
            inQueue = ids == genericValue1.source
        end

        if inQueue then
            if rtnTbl then
                return genericKey1, connecting and connList[genericKey1] or queueList[genericKey1]
            end

            return true
        end
    end

    return false
end

function StillPriority(ids)
    local prio = false
    local tempPower, tempEnd = HasTempPriority(ids)
    local prioList = self.Priority

    for _, id in ipairs(ids) do
        id = string_lower(id)

        if prioList[id] then
            prio = prioList[id]
            break
        end

        if string_sub(id, 1, 5) == "steam" then
            local steamid = ConvertHexToId(id)

            if prioList[steamid] then
                prio = prioList[steamid]
                break
            end
        end
    end

    if tempPower or prio then
        if tempPower and prio then
            return tempPower > prio and tempPower or prio
        else
            return tempPower or prio
        end
    end

    return false
end

function HasTempPriority(ids)
    local tmpPrio = self.TempPriority

    for _, id in pairs(ids) do
        id = string_lower(id)

        if tmpPrio[id] then
            return tmpPrio[id].power, tmpPrio[id].endTime, id
        end

        if string_sub(id, 1, 5) == "steam" then
            local steamid = ConvertHexToId(id)
            if tmpPrio[steamid] then
                return tmpPrio[steamid].power, tmpPrio[steamid].endTime, id
            end
        end
    end

    return false
end

function AddToQueue(ids, connectTime, name, src, deferrals)
    if StillInQueue(ids) then
        return
    end

    local tmp = {
        source = src,
        ids = ids,
        name = name,
        priority = StillPriority(ids) or (src == "debug" and math_random(0, 15)),
        timeout = 0,
        deferrals = deferrals,
        firstconnect = connectTime,
        queuetime = function()
            return (os_time() - connectTime)
        end
    }

    local _pos = false
    local queueCount = #self.QueueList + 1
    local queueList = self.QueueList

    for pos, data in ipairs(queueList) do
        if tmp.priority then
            if not data.priority then
                _pos = pos
            else
                if tmp.priority > data.priority then
                    _pos = pos
                end
            end

            if _pos then
                NKCore.SetPrint({type = 'info', title = 'Queue', message = '%s [%s] was prioritized and placed %d/%d in queue'}, tmp.name, ids[1], _pos, queueCount)
                break
            end
        end
    end

    if not _pos then
        _pos = #self.QueueList + 1
        NKCore.SetPrint({type = 'info', title = 'Queue', message = '%s [%s] was placed %d/%d in queue'}, tmp.name, ids[1], _pos, queueCount)
    end

    table_insert(queueList, _pos, tmp)
end

function DeleteFromQueue(ids, bySource, byIndex)
    local queueList = self.QueueList

    if byIndex then
        if queueList[byIndex] then
            table_remove(queueList, byIndex)
        end

        return
    end

    if StillInQueue(ids, false, bySource) then
        local pos, data = StillInQueue(ids, true, bySource)
        table_remove(queueList, pos)
    end
end

function TempSize()
    local count = 0

    for _pos, data in pairs(self.QueueList) do
        if HasTempPriority(data.ids) then
            count = count + 1
        end
    end

    return count > 0 and count or false
end

function StillInConnecting(ids, bySource, refresh)
    local inConnecting, tbl = StillInQueue(ids, refresh and true or false, bySource and true or false, true)

    if not inConnecting then
        return false
    end

    if refresh and inConnecting and tbl then
       self.Connecting[inConnecting].timeout = 0
    end

    return true
end

function DeleteFromConnecting(ids, bySource, byIndex)
    local connList = self.Connecting

    if byIndex then
        if connList[byIndex] then
            table_remove(connList, byIndex)
        end

        return
    end

    for genericKey1, genericValue1 in ipairs(connList) do
        local inConnecting = false

        if not bySource then
            for genericKey2, genericValue2 in ipairs(genericValue1.ids) do
                if inConnecting then
                    break
                end

                for genericKey3, genericValue3 in ipairs(ids) do
                    if genericValue3 == genericValue2 then
                        inConnecting = true
                        break
                    end
                end
            end
        else
            inConnecting = ids == genericValue1.source
        end

        if inConnecting then
            table_remove(connList, genericKey1)
            return true
        end
    end

    return false
end

function AddToConnecting(ids, ignorePos, autoRemove, done)
    local function remove()
        if not autoRemove then
            return
        end
    
        done(serverConfig.translate.connecting_error)
        DeleteFromConnecting(ids)
        DeleteFromQueue(ids)
        NKCore.SetPrint({type = 'error', title = 'Queue', message = 'Player could not be added to the connecting list'})
    end

    local connList = self.Connecting

    if #self.Connecting + self.PlayerCount + 1 > self.MaxPlayers then
        remove()
        return false
    end
    
    if ids[1] == "debug" then
        table_insert(connList, {source = ids[1], ids = ids, name = ids[1], firstconnect = ids[1], priority = ids[1], timeout = 0})
        return true
    end

    if StillInConnecting(ids) then
        DeleteFromConnecting(ids)
    end

    local pos, data = StillInQueue(ids, true)
    if not ignorePos and (not pos or pos > 1) then
        remove()
        return false
    end

    table_insert(connList, data)
    DeleteFromQueue(ids)

    return true
end

function GetIds(src)
    local ids = GetPlayerIdentifiers(src)
    local ip = GetPlayerEndpoint(src)

    ids = (ids and ids[1]) and ids or (ip and {"ip:" .. ip} or false)
    ids = ids ~= nil and ids or false

    if ids and #ids > 1 then
        for k, id in ipairs(ids) do
            if string_sub(id, 1, 3) == "ip:" and not StillPriority({id}) then
                table_remove(ids, k)
            end
        end
    end

    return ids
end

function AddPriority(id, power, temp)
    if not id then
        return false
    end

    if type(id) == "table" then
        for _id, power in pairs(id) do
            if _id and type(_id) == "string" and power and type(power) == "number" then
                self.Priority[_id] = power
            else
                NKCore.SetPrint({type = 'error', title = 'Queue', message = 'Error adding a priority id, invalid data passed'})
                return false
            end
        end

        return true
    end

    power = (power and type(power) == "number") and power or 10

    if temp then
        local tempPower, tempEnd, tempId = HasTempPriority({id})
        id = tempId or id

        self.TempPriority[string_lower(id)] = {power = power, endTime = os_time() + temp} 
    else
        self.Priority[string_lower(id)] = power
    end
    
    return true
end

function RemovePriority(id)
    if not id then
        return false
    end

    id = string_lower(id)
    self.Priority[id] = nil

    return true
end

function UpdatePosData(src, ids, deferrals)
    local pos, data = StillInQueue(ids, true)
    data.source = src
    data.ids = ids
    data.timeout = 0
    data.firstconnect = os_time()
    data.name = GetPlayerName(src)
    data.deferrals = deferrals
end

function NotFull(firstJoin)
    local canJoin = self.PlayerCount + #self.Connecting < self.MaxPlayers

    if firstJoin and canJoin then
        canJoin = #self.QueueList <= 1
    end

    return canJoin
end

function SetPos(ids, newPos)
    if newPos <= 0 or newPos > #self.QueueList then
        return false
    end

    local pos, data = StillInQueue(ids, true)
    local queueList = self.QueueList

    table_remove(queueList, pos)
    table_insert(queueList, newPos, data)
end

function CanJoin(src, cb)
    local allow = true

    for _, data in ipairs(self.JoinCbs) do
        local await = true

        data.func(src, function(reason)
            if reason and type(reason) == "string" then
                allow = false cb(reason)
            end

            await = false
        end)

        while await do
            Wait(0)
        end

        if not allow then
            return
        end
    end

    if allow then
        cb(false)
    end
end

function OnJoin(cb, resource)
    if not cb then
        return 
    end

    local tmp = {resource = resource, func = cb}
    table_insert(self.JoinCbs, tmp)
end

local function playerConnect(name, setKickReason, deferrals)
    local allow
    local src = source
    local rejoined = false
    local ids = GetIds(src)
    local name = GetPlayerName(src)
    local connectTime = os_time()
    local connecting = true

    deferrals.defer()
    
    Wait(500)

    local function done(msg, _deferrals)
        connecting = false

        local deferrals = _deferrals or deferrals

        if msg then
            AdaptiveCard(deferrals, serverConfig.translate.title, tostring(msg) or "")
        end

        Wait(500)

        if not msg then
            deferrals.done()

            if serverConfig.use_grace_system then
                AddPriority(ids[1], serverConfig.default_grace_level, serverConfig.grace_ability_length)
            end
        else
            deferrals.done(tostring(msg) or "")
            CancelEvent()
        end

        return
    end

    local function update(msg, _deferrals)
        local deferrals = _deferrals or deferrals
        connecting = false
        AdaptiveCard(deferrals, serverConfig.translate.title, tostring(msg) or "")
        Wait(1000)
    end

    if serverConfig.anti_spam.enable then
        for i=serverConfig.timer,0,-1 do
            AdaptiveCard(deferrals, serverConfig.translate.title, serverConfig.anti_spam.please_wait(i))
            Wait(1000)
        end
    end

    while not self.resourcesLoaded do
        AdaptiveCard(deferrals, serverConfig.translate.title, "The server is turning on, please wait a moment")
        Wait(1000)
    end

    AdaptiveCard(deferrals, serverConfig.translate.title, "Your data is being checked")
    Wait(1500)

    if not ids then
        done(serverConfig.translate.id_error)
        CancelEvent()
        NKCore.SetPrint({type = 'error', title = 'Queue', message = "Dropped %s because server couldn't retrieve any of their id's"}, name)
        return
    end

    AdaptiveCard(deferrals, serverConfig.translate.title, "Checking steam data account")
    Wait(1500)

    if serverConfig.use_steam and not IsSteamRunning(src) then
        done(serverConfig.translate.steam)
        CancelEvent()
        return
    end

    CanJoin(src, function(reason)
        if reason == nil or allow ~= nil then
            return
        end

        if reason == false or #self.JoinCbs <= 0 then
            allow = true
            return
        end

        if reason then
            allow = false
            done(reason and tostring(reason) or "You were blocked from joining")
            DeleteFromQueue(ids)
            DeleteFromConnecting(ids)
            NKCore.SetPrint({type = 'error', title = 'Queue', message = "%s [%s] was blocked from joining because %s"}, name, ids[1], reason)
            CancelEvent()
            return
        end

        allow = true
    end) 

    while allow == nil do
        Wait(0)
    end

    if not allow then
        return
    end

    if serverConfig.only_priority and not StillPriority(ids) then
        done(serverConfig.translate.wlonly)
        return
    end

    if StillInConnecting(ids, false, true) then
        DeleteFromConnecting(ids)

        if NotFull() then
            if not StillInQueue(ids) then
                AddToQueue(ids, connectTime, name, src, deferrals)
            end

            local added = AddToConnecting(ids, true, true, done)
            
            if not added then
                CancelEvent()
                return
            end

            done()

            return
        else
            rejoined = true
        end
    end

    if StillInQueue(ids) then
        rejoined = true
        UpdatePosData(src, ids, deferrals)
        NKCore.SetPrint({type = 'info', title = 'Queue', message = '%s [%s] has rejoined queue after cancelling'}, name, ids[1])
    else
        AddToQueue(ids, connectTime, name, src, deferrals)

        if rejoined then
            SetPos(ids, 1)
            rejoined = false
        end
    end

    local pos, data = StillInQueue(ids, true)

    if not pos or not data then
        done(serverConfig.translate.error .. " [1]")

        DeleteFromQueue(ids)
        DeleteFromConnecting(ids)

        CancelEvent()
        return
    end

    if NotFull(true) and self.JoinDelay <= GetGameTimer() then
        local added = AddToConnecting(ids, true, true, done)

        if not added then
            CancelEvent()
            return
        end

        done()
        NKCore.SetPrint({type = 'info', title = 'Queue', message = "%s [%s] is loading into the server"}, name, ids[1])
        return
    end

    update(string_format(serverConfig.translate.pos .. ((TempSize() and serverConfig.show_queue_temp) and " (" .. TempSize() .. " temp)" or "00:00:00"), pos, #self.QueueList, ""))

    if rejoined then
        return
    end

    while true do
        Wait(500)

        local pos, data = StillInQueue(ids, true)

        local function remove(msg)
            if data then
                if msg then
                    update(msg, data.deferrals)
                end

                DeleteFromQueue(data.source, true)
                DeleteFromConnecting(data.source, true)
            else
                DeleteFromQueue(ids)
                DeleteFromConnecting(ids)
            end
        end

        if not data or not data.deferrals or not data.source or not pos then
            remove("Removed from queue, queue data invalid :(")
            NKCore.SetPrint({type = 'error', title = 'Queue', message = '%s [%s] was removed from the queue because they had invalid data'}, name, ids[1])
            return
        end

        local endPoint = GetPlayerEndpoint(data.source)

        if not endPoint then
            data.timeout = data.timeout + 0.5
        else
            data.timeout = 0
        end

        if data.timeout >= serverConfig.queue_timeout_length and os_time() - connectTime > 5 then
            remove("Removed due to timeout")
            NKCore.SetPrint({type = 'error', title = 'Queue', message = '%s [%s] was removed from the queue because they timed out'}, name, ids[1])
            return
        end

        if pos <= 1 and NotFull() and self.JoinDelay <= GetGameTimer() then
            local added = AddToConnecting(ids)

            update(serverConfig.translate.joining, data.deferrals)
            Wait(500)

            if not added then
                done(serverConfig.translate.connecting_error)
                CancelEvent()
                return
            end

            done(nil, data.deferrals)

            if serverConfig.use_grace_system then
                AddPriority(ids[1], serverConfig.default_grace_level, serverConfig.grace_ability_length)
            end

            DeleteFromQueue(ids)
            NKCore.SetPrint({type = 'info', title = 'Queue', message = '%s [%s] is loading into the server'}, name, ids[1])
            return
        end

        local seconds = data.queuetime()
        local qTime = string_format("%02d", math_floor((seconds % 86400) / 3600)) .. ":" .. string_format("%02d", math_floor((seconds % 3600) / 60)) .. ":" .. string_format("%02d", math_floor(seconds % 60))

        local msg = string_format(serverConfig.translate.pos .. ((TempSize() and serverConfig.show_queue_temp) and " (" .. TempSize() .. " temp)" or ""), pos, #self.QueueList, qTime)
        update(msg, data.deferrals)
    end
end

AddEventHandler("playerConnecting", playerConnect)

CreateThread(function()
    local function remove(data, pos, msg)
        if data and data.source then
            DeleteFromQueue(data.source, true)
            DeleteFromConnecting(data.source, true)
        elseif pos then
            table_remove(self.QueueList, pos)
        end
    end

    while true do
        Wait(1000)
    
        local i = 1
    
        while i <= #self.Connecting do
            local data = self.Connecting[i]
    
            local endPoint = GetPlayerEndpoint(data.source)
    
            data.timeout = data.timeout + 1
    
            if ((data.timeout >= 300 and not endPoint) or data.timeout >= serverConfig.queue_timeout_length) and data.source ~= "debug" and os_time() - data.firstconnect > 5 then
                remove(data)
                NKCore.SetPrint({type = 'error', title = 'Queue', message = '%s [%s] was removed from the connecting queue because they timed out'}, data.name, data.ids[1])
            else
                i = i + 1
            end
        end

        for id, data in pairs(self.TempPriority) do
            if os_time() >= data.endTime then
                self.TempPriority[id] = nil
            end
        end
    
        self.MaxPlayers = GetConvarInt("sv_maxclients", 30)
        self.DisplayQueue = GetConvar("sv_displayqueue", "true") == "true" and true or false

        local qCount = #self.QueueList

        if self.DisplayQueue then
            if self.InitHostName then
                SetConvar("sv_hostname", (qCount > 0 and "[" .. tostring(qCount) .. "] " or "") .. self.InitHostName)
            else
                self.InitHostName = GetConvar("sv_hostname")
                self.InitHostName = self.InitHostName ~= "default FXServer" and self.InitHostName or false
            end
        end
    end
end)

CreateThread(
    function()
        while true do
            Wait(100)
            local loaded = true
            for i = 1, GetNumResources() do
                local res = GetResourceByFindIndex(i)
                if res then
                    local resState = GetResourceState(res)
                    if resState == "missing" or resState == "starting" or resState == "uninitialized" or resState == "unknown" then
                        loaded = false
                        break
                    end
                end
            end

            if loaded then
                self.resourcesLoaded = true
                break
            end
        end
    end
)

AddEventHandler("playerDropped", function()
    local src = source
    local ids = NKCore.PlayerIdentifierData(src)

    if self.PlayerList[src] then
        self.PlayerCount = self.PlayerCount - 1
        self.PlayerList[src] = nil
        DeleteFromQueue(ids)
        DeletFromConnecting(ids)
        if serverConfig.use_grace_syste then
            AddPriority(ids.steam, serverConfig.default_grace_level, serverConfig.grace_ability_length)
        end
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if self.DisplayQueue and self.InitHostName and resource == GetCurrentResourceName() then
        SetConvar("sv_hostname", self.InitHostName)
    end
    
    for k, data in ipairs(self.JoinCbs) do
        if data.resource == resource then
            table_remove(self.JoinCbs, k)
        end
    end
end)

if serverConfig.disable_hardcap then
    NKCore.SetPrint({type = 'error', title = 'Queue', message = 'Disabling hardcap resource'})

    AddEventHandler("onResourceStarting", function(resource)
        if resource == "hardcap" then
            CancelEvent()
            return
        end
    end)
    
    StopResource("hardcap")
end
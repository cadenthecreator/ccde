local max_distance = 220

local pullEvent = os.pullEventRaw
local modem = peripheral.find("modem",function (s) return peripheral.wrap(s).isWireless() end)
term.clear()
term.setCursorPos(1,1)
_G.network = {}
if not modem then
    return
end
local message_queue = {}
modem.open(15125)
local canidate = {id = -1, distance = max_distance}
parallel.waitForAny(function () repeat sleep(0.1) until canidate.id ~= -1 end,
function ()
    while true do
        local _, _, channel, _, msg, distance = pullEvent("modem_message")
        if channel == 15125 then
            if msg.protocol == "entrypoint_advertise" then
                if distance < canidate.distance then
                    canidate.id = msg.sender
                    canidate.distance = distance
                end
            end
        end
    end
end)
local last_heartbeat = os.epoch("utc")
modem.transmit(15125,15125,{protocol="entrypoint_connect",sender=os.getComputerID(),target=canidate.id})

local function receive()
    while true do
        local _, _, channel, _, msg, distance = pullEvent("modem_message")
        if channel == 15125 then
            if msg.protocol == "heartbeat" and msg.target == os.getComputerID() and msg.sender == canidate.id then
                last_heartbeat = os.epoch("utc")
                modem.transmit(15125,15125,{protocol="heartbeat_response",sender=os.getComputerID(),target=canidate.id})
                if distance > max_distance then
                    modem.transmit(15125,15125,{protocol="entrypoint_disconnect",sender=os.getComputerID(),target=canidate.id})
                    canidate = {id = -1, distance = max_distance}
                    parallel.waitForAny(function () repeat sleep(0.1) until canidate.id ~= -1 end,
                    function ()
                        while true do
                            local _, _, channel, _, msg, distance = pullEvent("modem_message")
                            if channel == 15125 then
                                if msg.protocol == "entrypoint_advertise" then
                                    if distance < canidate.distance then
                                        canidate.id = msg.sender
                                        canidate.distance = distance
                                    end
                                end
                            end
                        end
                    end)
                    if canidate.id == -1 then
                        sleep(5)
                    else
                        modem.transmit(15125,15125,{protocol="entrypoint_connect",sender=os.getComputerID(),target=canidate.id})
                        last_heartbeat = os.epoch("utc")
                    end
                end
            elseif msg.protocol == "packet" then
                if msg.hops >= 1 then
                    os.queueEvent("network_packet",msg.content,msg.sender,msg.hops)
                end
            end
        end
    end
end

function _G.network.send(msg,destination)
    if not msg then error("No message provided",2) end
    if not destination then error("No destination provided",2) end
    message_queue[#message_queue+1] = {protocol="packet",content=msg,destination=destination,sender=os.getComputerID(),hops=0}
end

local function connect()
    while true do
        if os.epoch("utc") - last_heartbeat > 200 then
            canidate = {id = -1, distance = max_distance}
            parallel.waitForAny(function () repeat sleep(0.1) until canidate.id ~= -1 end,
            function ()
                while true do
                    local _, _, channel, _, msg, distance = pullEvent("modem_message")
                    if channel == 15125 then
                        if msg.protocol == "entrypoint_advertise" then
                            if distance < canidate.distance then
                                canidate.id = msg.sender
                                canidate.distance = distance
                            end
                        end
                    end
                end
            end)
            if canidate.id == -1 then
                sleep(5)
            else
                modem.transmit(15125,15125,{protocol="entrypoint_connect",sender=os.getComputerID(),target=canidate.id})
                last_heartbeat = os.epoch("utc")
            end
        else
                local msg = table.remove(message_queue,1)
                if msg then
                    modem.transmit(15125,15125,msg)
                end
        end
        sleep()
    end
end
parallel.waitForAny(receive, connect)
os.shutdown()

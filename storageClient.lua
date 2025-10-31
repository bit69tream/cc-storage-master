MODEM = peripheral.wrap("back")

local function setupRednetClient()
  os.setComputerLabel("StorageClient")
  rednet.open(peripheral.getName(MODEM))
end

setupRednetClient()

SERVER = rednet.lookup("storage", "main")
if SERVER == nil then
  error("Please start the server first")
end

rednet.send(SERVER, { code = "PING" }, "storage")
local id, msg = rednet.receive("storage")
if id == nil or id ~= SERVER then
  error("sussy")
end
if msg == nil then
  error("expected PONG")
end
textutils.serialize(msg)

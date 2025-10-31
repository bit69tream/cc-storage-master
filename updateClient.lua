MODEM = peripheral.wrap("back")

if MODEM == nil then
  error("your pocket computer needs a modem")
end

local function setupRednetClient()
  os.setComputerLabel("StorageClient")
  rednet.open(peripheral.getName(MODEM))
end

setupRednetClient()

GLB.server = rednet.lookup("storage", "main")
if GLB.server == nil then
  error("Please start the server first")
end

local function requestUpdate()
  print("requesting client update")
  rednet.send(GLB.server, { code = "CLIENT" }, "storage")
end

local function receiveUpdate()
  local id, msg = rednet.receive("storage", 5)
  if id == nil then
    error("the server is probably down.. :(")
  end
  if msg == nil or msg.data == nil then
    error("the server is set up incorrectly")
  end

  local file = fs.open("storageClient.lua", "w")
  if file == nil then
    error("could not open storageClient.lua for writing")
  end
  file.write(msg.data)
  file.close()

  print("the client is up to date")
end

parallel.waitForAll(requestUpdate, receiveUpdate)

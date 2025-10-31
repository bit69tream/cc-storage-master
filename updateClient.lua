GLB = {
  modem = peripheral.wrap("back"),
  server = rednet.lookup("storage", "main"),
}

if GLB.modem == nil then
  error("your pocket computer needs a modem")
  os.exit(69)
end

local function setupRednetClient()
  os.setComputerLabel("StorageClient")
  rednet.open(peripheral.getName(GLB.modem))
end

setupRednetClient()

if GLB.server == nil then
  error("Please start the server first")
  os.exit(69)
end

local function requestUpdate()
  print("requesting client update")
  rednet.send(GLB.server, { code = "CLIENT" }, "storage")
end

local function receiveUpdate()
  local id, msg = rednet.receive("storage", 5)
  if id == nil then
    error("the server is probably down.. :(")
    os.exit(69)
  end
  if msg == nil then
    error("the server is set up incorrectly")
    os.exit(69)
  end

  if msg.code ~= "CLIENT_UPDATE" then
    if msg.code == "ERROR" then
      error("server responded with: " .. msg.error)
      os.exit(69)
    end

    error("something's not right with the server")
    os.exit(69)
  end

  local file = fs.open("storageClient.lua", "w")
  if file == nil then
    error("could not open storageClient.lua for writing")
    os.exit(69)
  end
  file.write(msg.data)
  file.close()

  print("the client is up to date")
end

parallel.waitForAll(requestUpdate, receiveUpdate)

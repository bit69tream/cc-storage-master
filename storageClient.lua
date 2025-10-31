MODEM_PERIPHERAL = "back"
PROTOCOL = "storage"
GLB = {
  modem = nil,
  server = nil,
}

local function checkServer()
  term.write("checking server....")

  parallel.waitForAll(function()
      rednet.send(GLB.server, { code = "PING" }, PROTOCOL)
    end,
    function()
      local id, msg = rednet.receive(PROTOCOL, 2)

      if id == nil or msg == nil then
        error("The server isn't running")
        os.exit(69)
      end

      if msg.code ~= "PONG" then
        error("The server isn't set up correctly")
        os.exit(69)
      end

      print("the server is running correctly")
    end)
end

local function setupRednetClient()
  GLB.modem = peripheral.wrap(MODEM_PERIPHERAL)
  os.setComputerLabel("Storage Client")
  rednet.open(MODEM_PERIPHERAL)

  GLB.server = rednet.lookup(PROTOCOL, "main")
  if GLB.server == nil then
    error("Please set the server up first")
    os.exit(69)
  end
end

local function init()
  print("initializing...")

  setupRednetClient()
  print("configured wireless connection")

  checkServer()
end

init()

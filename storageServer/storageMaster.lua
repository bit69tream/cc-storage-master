PROTOCOL = "storage"

-- global variables unrelated to UI
GLB = {
  -- list of wrapped storage peripherals
  storage = {},
  modem = {},
  dnsId = 0,

  invBuffer = "",
  invManager = {},

  ownName = "",
}

function DUMP(o)
  if type(o) == 'table' then
    local s = '{ '
    for k, v in pairs(o) do
      if type(k) ~= 'number' then k = '"' .. k .. '"' end
      s = s .. '[' .. k .. '] = ' .. DUMP(v) .. ','
    end
    return s .. '} '
  else
    return tostring(o)
  end
end

local function findWirelessModem()
  return peripheral.find("modem", function(_, modem) return modem.isWireless() end)
end

local function collectStorage()
  local periheralList = peripheral.getNames()
  local storage = {}

  for i = 1, #periheralList do
    local p = periheralList[i]
    local _, type = peripheral.getType(p)
    if p ~= GLB.invBuffer and type == "inventory" then
      table.insert(storage, peripheral.wrap(p))
    end
  end

  return storage
end

local function setupRedNetServer()
  os.setComputerLabel("Storage Master")
  rednet.open(peripheral.getName(GLB.modem))
  rednet.host(PROTOCOL, "main")
end

local function getNameFromDNS(name)
  Name = ""

  parallel.waitForAll(
    function()
      rednet.send(GLB.dnsId, name, "dns")
    end,
    function()
      local id, msg = rednet.receive("dns")
      assert(id)

      if msg == nil or type(msg) ~= "string" or msg == "UNKNOWN" then
        error("please configure your DNS server for 'storage turtle'")
        os.exit(69)
      end

      Name = msg
    end
  )

  return Name
end

local function checkPeripheral(name, optStorageType)
  local prph = peripheral.wrap(name)
  if prph == nil then
    error("peripheral '" .. name .. "' doesn't exist")
    os.exit(69)
  end

  if optStorageType == nil then
    return
  end

  local typ = { peripheral.getType(prph) }
  local hasType = false
  for i = 1, #typ do
    if typ[i] == optStorageType then
      hasType = true
      break
    end
  end

  if not hasType then
    error("peripheral's '" .. name .. "' type doesn't satisfy '" .. optStorageType .. "' requirement")
    os.exit(69)
  end
end

local function getPeripheralsFromDNS()
  local dnsId = rednet.lookup("dns", "dns")

  if dnsId == nil then
    error("you must first run the DNS server")
    os.exit(69)
  end

  GLB.dnsId = dnsId
  GLB.ownName = getNameFromDNS("storage turtle")
  print("got 'storage turtle' from DNS:", GLB.ownName)

  local invManager = getNameFromDNS("inventory manager")
  print("got 'inventory manager' from DNS: ", invManager)

  GLB.invManager = peripheral.wrap(invManager)

  GLB.invBuffer = getNameFromDNS("inventory manager buffer")
  print("got 'inventory manager buffer' from DNS:", GLB.invBuffer)
  checkPeripheral(GLB.invBuffer, "inventory")

  if peripheral.wrap(GLB.invBuffer).size() < 27 then
    error("player inventory buffer needs to be at least 27 slots long")
    os.exit(69)
  end
end

local function init()
  if turtle == nil then
    error("This computer must be a turtle")
    os.exit(69)
  end

  term.clear()
  term.setCursorPos(1, 1)
  -- print("checking config..")
  -- checkConfig()

  print("initializing...")

  term.write("looking for wireless modem...")
  GLB.modem = findWirelessModem()
  print("done")

  term.write("setting up wireless communication...")
  setupRedNetServer()
  print("done")

  print("getting peripherals from DNS:")
  getPeripheralsFromDNS()

  term.write("collecting storage peripherals...")
  GLB.storage = collectStorage()
  print("found " .. #GLB.storage .. " containers in network")
end

local function getFancyItemList()
  ---@type { displayName: string; name: string; count: number; nbt: string|nil; }[]
  local items = {}

  for i = 1, #GLB.storage do
    local inv = GLB.storage[i]

    for islot = 1, inv.size() do
      print(i, islot)
      local details = inv.getItemDetail(islot)
      if details == nil then
        goto continue
      end

      items[#items + 1] = {
        displayName = details.displayName,
        name = details.name,
        count = details.count,
        nbt = details.nbt,
      }

      ::continue::
    end
  end

  return items
end

local function getPlayerInventory()
  return GLB.invManager.getItems()
end

init()

MESSAGE_SWITCH = {
  ["PING"] = function(id, _)
    rednet.send(id, { code = "PONG" }, PROTOCOL)
  end,
  ["CLIENT"] = function(id, _)
    local file = fs.open("/disk/storageClient/storageClient.lua", "r")
    if file == nil then
      error("/disk/storageClient.lua isn't accessible")
      rednet.send(id, { code = "ERROR", error = "Unable to send the client program" })
    end
    local data = file.readAll()
    file.close()

    rednet.send(id, { code = "CLIENT_DATA", data = data }, PROTOCOL)
  end,
  ["GET_ITEMS"] = function(id, _)
    local items = getFancyItemList()
    rednet.send(id, { code = "ITEM_LIST", data = items })
  end,
  ["GET_PLAYER_INV"] = function (id, _)
    local items = getPlayerInventory()
    rednet.send(id, { code = "PLAYER_INVENTORY", data = items }, PROTOCOL)
  end
}

while true do
  local id, msg = rednet.receive(PROTOCOL)

  if id == nil then
    goto continue
  end

  if msg ~= nil and MESSAGE_SWITCH[msg.code] ~= nil then
    print("received message", msg.code, "from", id)
    MESSAGE_SWITCH[msg.code](id, msg)
  else
    rednet.send(id, { code = "ERROR", error = "unknown message type" })
  end

  ::continue::
end

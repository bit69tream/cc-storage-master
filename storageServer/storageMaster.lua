PROTOCOL = "storage"

-- global variables unrelated to UI
GLB = {
  -- list of wrapped storage peripherals
  storage = {},
  dnsId = 0,
  cacheServers = {},

  invBuffer = "",
  invManager = {},
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

local function setupRedNetServer()
  os.setComputerLabel("Storage Master")
  local modem = peripheral.find("modem", function(_, m) return m.isWireless() end)
  rednet.open(peripheral.getName(modem))
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
        error("please configure your DNS server for '" .. name .. "'")
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
  term.write("looking for dns server")
  local dnsId = nil
  for _ = 1, 5 do
    dnsId = rednet.lookup("dns", "dns")

    if dnsId ~= nil then
      break
    end

    term.write(".")
    sleep(0.1)
  end
  print("\nfound dns server:", dnsId)

  if dnsId == nil then
    error("you must first run the DNS server")
    os.exit(69)
  end

  GLB.dnsId = dnsId

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

local function collectStorage()
  MainStorage = {}

  parallel.waitForAll(
    function()
      rednet.send(GLB.dnsId, "main storage", "dns")
    end,
    function()
      local id, msg = rednet.receive("dns")
      assert(id)

      if msg == nil or type(msg) ~= "table" or msg == "UNKNOWN" then
        error("please configure your DNS server for 'main storage'")
        os.exit(69)
      end

      MainStorage = msg
    end
  )

  print("got main storage from DNS:", DUMP(MainStorage))

  for i = 1, #MainStorage do
    table.insert(GLB.storage, peripheral.wrap(MainStorage[i]))
  end
end

local function getCacheServersFromDNS()
  while #GLB.cacheServers == 0 do
    parallel.waitForAll(
      function()
        rednet.send(GLB.dnsId, "cache servers", "dns")
      end,
      function()
        local id, msg = rednet.receive("dns")
        assert(id == GLB.dnsId)
        assert(msg)

        if msg.code == "WAITABIT" then
          return
        elseif msg.code == "CACHE_SERVERS" then
          GLB.cacheServers = msg.data
        end
      end
    )
    sleep(0.1)
  end

  print("got cache server from DNS:", DUMP(GLB.cacheServers))
end

local function setupCacheServers()
  local servers = GLB.cacheServers
  local storage = GLB.storage

  local storageSizeSlots = 0
  for i = 1, #storage do
    storageSizeSlots = storageSizeSlots + storage[i].size()
  end
  print("total slots in storage:", storageSizeSlots)

  local slotsPerServer = storageSizeSlots / #servers

  print("slots per cache server:", slotsPerServer)

  local serverIndex = 1
  for i = 1, #storage do
    local currSlot = 1
    local slots = storage[i].size()

    while currSlot < slots do
      local range = {from = currSlot, upto = currSlot + slotsPerServer - 1}
      rednet.send(
        servers[serverIndex],
        {
          code = "SETUP",
          peripheral = peripheral.getName(storage[i]),
          range = range
        },
        "cache")
      print("cache server", servers[serverIndex], DUMP(range))

      currSlot = currSlot + slotsPerServer
      serverIndex = serverIndex + 1
    end
  end
end

local function init()
  term.clear()
  term.setCursorPos(1, 1)

  print("initializing...")

  term.write("setting up wireless communication...")
  setupRedNetServer()
  print("done")

  print("getting utility peripherals from DNS:")
  getPeripheralsFromDNS()

  print("getting storage cache servers from DNS:")
  getCacheServersFromDNS()

  term.write("getting storage peripherals from DNS: ")
  collectStorage()
  print("found " .. #GLB.storage .. " containers in network")

  print("setting up cache servers...")
  setupCacheServers()
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
  ["GET_PLAYER_INV"] = function(id, _)
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

PROTOCOL = "storage"

-- global variables unrelated to UI
GLB = {
  -- list of wrapped storage peripherals
  storage = {},
  dnsId = 0,
  cacheServers = {},

  invBuffer = {},
  ---@type {removeItemFromPlayer: function, getItems: function, addItemToPlayer: function}
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
      ::start::
      local id, msg = rednet.receive("dns")
      assert(id)
      if id ~= GLB.dnsId then
        goto start
      end

      if msg == nil or type(msg) ~= "string" or msg == "UNKNOWN" then
        error("please configure your DNS server for '" .. name .. "'")
        os.exit(69)
      end

      Name = msg
    end
  )

  return Name
end

local function checkPeripheral(prph, optStorageType)
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
    error("peripheral '" .. peripheral.getName(prph) .. "' type doesn't satisfy '" .. optStorageType .. "' requirement")
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

  local invBuffer = getNameFromDNS("inventory manager buffer")
  print("got 'inventory manager buffer' from DNS:", invBuffer)
  checkPeripheral(invBuffer, "inventory")
  GLB.invBuffer = peripheral.wrap(invBuffer)

  if GLB.invBuffer.size() < 27 then
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
        ::start::
        local id, msg = rednet.receive("dns")
        if id ~= GLB.dnsId then
          goto start
        end

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
      local range = { from = currSlot, upto = currSlot + slotsPerServer - 1 }
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

---@return { displayName: string; name: string; count: number; nbt: string|nil; peripheral: string; slot: number}[]
local function getFancyItemList()
  ---@type { displayName: string; name: string; count: number; nbt: string|nil; peripheral: string; slot: number}[]
  local items = {}

  rednet.broadcast({ code = "GET_ITEMS" }, "cache")
  for _ = 1, #GLB.cacheServers do
    local id, msg = rednet.receive("cache", 2)

    assert(id)
    assert(msg)
    assert(msg.code == "ITEMS_LIST")

    for i = 1, #msg.data do
      items[#items + 1] = msg.data[i]
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
  ["GET_STORAGE"] = function(id, _)
    local items = getFancyItemList()
    rednet.send(id, { code = "STORAGE", data = items }, PROTOCOL)
  end,
  ["GET_PLAYER_INV"] = function(id, _)
    local items = getPlayerInventory()
    rednet.send(id, { code = "PLAYER_INVENTORY", data = items }, PROTOCOL)
  end,
  ["REQUEST_ITEM"] = function(_, msg)
    ---@type {name: string, nbt: string, peripheral:string, count: number}
    local item = msg.data
    local storageItems = getFancyItemList()
    local invBuffer = peripheral.getName(GLB.invBuffer)

    ---@type {slot:number, peripheral: string, count:number}
    local itemsForSending = {}

    for i = 1, #storageItems do
      local found = false

      if item.count <= 0 then
        break
      end

      if item.nbt ~= nil then
        if item.nbt == storageItems[i].nbt and item.name == storageItems[i].name then
          found = true
        end
      else
        if item.name == storageItems[i].name then
          found = true
        end
      end

      if found then
        local count = math.min(storageItems[i].count, item.count)
        itemsForSending[#itemsForSending + 1] = {
          slot = storageItems[i].slot,
          peripheral = storageItems[i].peripheral,
          count = count,
        }
        item.count = item.count - count
      end
    end

    for i = 1, #itemsForSending do
      GLB.invBuffer.pullItems(itemsForSending[i].peripheral, itemsForSending[i].slot, itemsForSending[i].count)
      GLB.invManager.addItemToPlayer("up", {})
    end

  end,
  ["SEND_FROM_INV"] = function(_, msg)
    local opts = {
      name = msg.data.name,
      fromSlot = msg.data.slot,
      count = msg.data.count,
    }
    print(DUMP(opts))

    GLB.invManager.removeItemFromPlayer("up", opts)

    local chest = GLB.invBuffer
    assert(chest)
    for i = 1, chest.size() do
      if chest.getItemDetail(i) ~= nil then
        for j = 1, #GLB.storage do
          if chest.pushItems(peripheral.getName(GLB.storage[j]), i) ~= 0 then
            break
          end
        end
      end
    end
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

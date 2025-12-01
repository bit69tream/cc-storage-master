PROTOCOL = "storage"

-- global variables unrelated to UI
GLB = {
  -- list of wrapped storage peripherals
  storage = {},
  ---@type {drawer: table, separateCache: boolean|nil, filter: string[]}[]
  drawerStorage = {},
  dnsId = 0,
  cacheServers = {},
  drawerCacheServers = {},

  ---@type {id: number, recipes: string[]}[]
  autocrafters = {},

  invBuffer = {},
  ---@type {removeItemFromPlayer: function, getItems: function, addItemToPlayer: function}
  invManager = {},
  ---@type {sendMessage: function}
  chatBox = {},
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

---@param message string
local function sendChatMessage(message)
  GLB.chatBox.sendMessage(message, "John Storage", "<>", "&b")
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

  local chatbox = getNameFromDNS("chat box")
  print("got 'chat box' from DNS:", chatbox)
  GLB.chatBox = peripheral.wrap(chatbox)
end

local function collectStorage()
  MainStorage = {}
  DrawerStorage = {}

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

  parallel.waitForAll(
    function()
      rednet.send(GLB.dnsId, "drawer storage", "dns")
    end,
    function()
      local id, msg = rednet.receive("dns")
      assert(id)

      if msg == nil or type(msg) ~= "table" or msg == "UNKNOWN" then
        error("please configure your DNS server for 'main storage'")
        os.exit(69)
      end

      DrawerStorage = msg
    end
  )
  print("got drawer storage from DNS:", DUMP(DrawerStorage))

  for i = 1, #MainStorage do
    table.insert(GLB.storage, peripheral.wrap(MainStorage[i]))
  end

  for i = 1, #DrawerStorage do
    table.insert(GLB.drawerStorage, {
      drawer = peripheral.wrap(DrawerStorage[i].name),
      filter = DrawerStorage[i].filter,
      separateCache = DrawerStorage[i].separateCache,
    })
  end
end

local function getDrawerCacheServersFromDNS()
  while #GLB.drawerCacheServers == 0 do
    parallel.waitForAll(
      function()
        rednet.send(GLB.dnsId, "drawer cache servers", "dns")
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
        elseif msg.code == "DRAWER_CACHE_SERVERS" then
          GLB.drawerCacheServers = msg.data
        end
      end
    )
    sleep(0.1)
  end

  print("got drawer cache server from DNS:", DUMP(GLB.drawerCacheServers))
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

local function setupMainCacheServers()
  local servers = GLB.cacheServers
  local storage = GLB.storage

  local storageSizeSlots = 0
  for i = 1, #storage do
    storageSizeSlots = storageSizeSlots + storage[i].size()
  end
  print("total slots main in storage:", storageSizeSlots)

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
      -- print("cache server", servers[serverIndex], DUMP(range))

      currSlot = currSlot + slotsPerServer
      serverIndex = serverIndex + 1
    end
  end
end

local function setupDrawerCacheServers()
  local servers = GLB.drawerCacheServers
  local storage = GLB.drawerStorage

  local separateDrawers = {}

  local drawerNames = {}
  for i = 1, #storage do
    if storage[i].separateCache then
      separateDrawers[#separateDrawers + 1] = peripheral.getName(storage[i].drawer)
    else
      drawerNames[#drawerNames + 1] = peripheral.getName(storage[i].drawer)
    end
  end

  print(DUMP(servers))

  assert(#servers == 1 + #separateDrawers)

  for i = 1, #separateDrawers do
    rednet.send(servers[i], { code = "SETUP", data = { separateDrawers[i] } }, "cache")
    print("drawer cache server", servers[i], separateDrawers[i])
  end

  rednet.send(servers[#servers], { code = "SETUP", data = drawerNames }, "cache")
  print("drawer cache server", servers[#servers], DUMP(drawerNames))
end

local function getAutocrafters()

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
  getDrawerCacheServersFromDNS()

  term.write("getting storage peripherals from DNS: ")
  collectStorage()
  print("found " .. #GLB.storage + #GLB.drawerStorage .. " containers in network")

  print("setting up cache servers...")
  setupMainCacheServers()
  setupDrawerCacheServers()

  print("getting crafting computers...")
  getAutocrafters()

  sendChatMessage("Storage initialized successfully")
end

---@return { displayName: string; name: string; count: number; nbt: string|nil; peripheral: string; slot: number}[]
local function getFancyItemList()
  ---@type { displayName: string; name: string; count: number; nbt: string|nil; peripheral: string; slot: number}[]
  local items = {}

  rednet.broadcast({ code = "GET_ITEMS" }, "cache")
  for _ = 1, #GLB.cacheServers + #GLB.drawerCacheServers do
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

local function pushEverythingIntoStorage(from)
  local storage = GLB.storage
  local drawerStorage = GLB.drawerStorage

  for k, v in pairs(from.list()) do
    for j = 1, #drawerStorage do
      local filter = drawerStorage[j].filter
      local canInsert = false
      for f = 1, #filter do
        if filter[f] == v.name then
          canInsert = true
          break
        end
      end

      if canInsert then
        local pushed = from.pushItems(peripheral.getName(drawerStorage[j].drawer), k)
        print("pushed", pushed, "into", peripheral.getName(drawerStorage[j].drawer), "from slot", k)
        goto continue
      end
    end

    for j = 1, #storage do
      if from.pushItems(peripheral.getName(storage[j]), k) ~= 0 then
        break
      end
    end

    ::continue::
  end
end

---@param to table
---@param item {name: string, nbt: string, count: number}
---@return {slot:number, peripheral: string, count:number}[]
local function pullItemFromStorage(to, item)
  ---@type {slot:number, peripheral: string, count:number}[]
  local result = {}
  local storageItems = getFancyItemList()
  local stackLimit = to.getItemLimit(1)

  for i = 1, #storageItems do
    if item.count <= 0 then
      break
    end

    if item.nbt == storageItems[i].nbt and item.name == storageItems[i].name then
      local count = math.min(storageItems[i].count, item.count)
      local slots = math.ceil(count / stackLimit)

      for _ = 1, slots do
        local slotCount = math.min(count, stackLimit)
        result[#result + 1] = {
          slot = storageItems[i].slot,
          peripheral = storageItems[i].peripheral,
          count = slotCount,
        }
        item.count = item.count - slotCount
        count = count - slotCount
      end
    end
  end

  return result
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
  ["PUSH_INTO_STORAGE"] = function(_, msg)
    local from = peripheral.wrap(msg.peripheral)
    assert(from)

    pushEverythingIntoStorage(from)
  end,
  ["REQUEST_ITEM"] = function(_, msg)
    ---@type {name: string, nbt: string, peripheral:string, count: number}
    local item = msg.data

    local itemsForSending = pullItemFromStorage(GLB.invBuffer, item)

    local deliveredCount = 0
    for i = 1, #itemsForSending do
      deliveredCount = deliveredCount + itemsForSending[i].count
      GLB.invBuffer.pullItems(itemsForSending[i].peripheral, itemsForSending[i].slot, itemsForSending[i].count)
      GLB.invManager.addItemToPlayer("up", {})
    end

    sendChatMessage("Delivered " .. deliveredCount .. " of [" .. item.name .. "]")
  end,
  -- NOTE: to avoid fragmentation we can ask cache servers to send us a list of
  -- non-empty but also non-full slots with a particular item and insert out
  -- items into those slots, and only then we will fill the empty slots
  ["SEND_FROM_INV"] = function(_, msg)
    ---@type {name: string, count: number, nbt: string}
    local opts = msg.data
    print(DUMP(opts))

    ---@type {name: string, nbt: string, count: number, slot: number}[]
    local playerInv = GLB.invManager.getItems()

    local sentAmount = 0
    for i = 1, #playerInv do
      -- for some reason inventory manager sets `nbt` to an empty table value rather that nil
      if (playerInv[i].nbt == opts.nbt or
            (#playerInv[i].nbt == 0 and #opts.nbt == 0)) and
          playerInv[i].name == opts.name then
        local count = math.min(opts.count, playerInv[i].count)
        GLB.invManager.removeItemFromPlayer("up", {
          name = opts.name,
          count = count,
          fromSlot = playerInv[i].slot
        })
        opts.count = opts.count - count
        sentAmount = sentAmount + count
      end
    end

    local chest = GLB.invBuffer
    assert(chest)

    pushEverythingIntoStorage(chest)
    sendChatMessage("Received " .. sentAmount .. " of [" .. opts.name .. "]")
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

PROTOCOL = "storage"

-- global variables unrelated to UI
GLB = {
  -- list of wrapped storage peripherals
  storage = {},
  modem = {},
  dnsId = {},

  invBuffer = "",
  ownName = "",
}

-- global variables related to UI
UISTATE = {}

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

local function getItemList()
  -- scheme:
  --   name
  --   count
  local items = {}

  for i = 1, #GLB.storage do
    -- get list of items from a current storage
    local currentItems = GLB.storage[i].list()

    -- check if the item is already in `items`
    for j = 1, #currentItems do
      local itemAlreadyInList = false
      for k = 1, #items do
        if not currentItems[j] then
          goto continue
        end

        if items[k].name == currentItems[j].name then
          itemAlreadyInList = true
          items[k].count = items[k].count + currentItems[j].count
        end
        ::continue::
      end

      if currentItems[j] and not itemAlreadyInList then
        table.insert(items, currentItems[j])
      end
    end
  end

  table.sort(items, function(a, b) return a.name < b.name end)

  return items
end

local function setupRedNetServer()
  os.setComputerLabel("Storage Master")
  rednet.open(peripheral.getName(GLB.modem))
  rednet.host(PROTOCOL, "main")
end

-- local function checkConfig()
--   local invManagerChest = peripheral.wrap(CONFIG.invManagerChestName)
--   if invManagerChest == nil or peripheral.getType(invManagerChest) ~= "inventory" then
--     error("CONFIG.invManagerChestName is either missing or isn't an inventory")
--     os.exit(69)
--   end
--
--   me = peripheral.wrap(CONFIG.ownName)
-- end

local function getNameFromDNS(name)
  Name = ""

  parallel.waitForAll(
    function ()
      rednet.send(GLB.dnsId, name, "dns")
    end,
    function ()
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

local function getNamesFromDNS()
  local dnsId = rednet.lookup("dns", "dns")

  if dnsId == nil then
    error("you must first run the DNS server")
    os.exit(69)
  end

  GLB.dnsId = dnsId
  GLB.ownName = getNameFromDNS("storage turtle")
  print("got 'storage turtle' from DNS:", GLB.ownName)
  GLB.invBuffer = getNameFromDNS("player inventory buffer")
  print("got 'player inventory buffer' from DNS:", GLB.invBuffer)
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

  GLB.modem = findWirelessModem()
  setupRedNetServer()
  print("set up wireless communication")

  print("getting peripherals from DNS")
  getNamesFromDNS()

  GLB.storage = collectStorage()
  print("found " .. #GLB.storage .. " containers in network")
end

init()

MESSAGE_SWITCH = {
  ["PING"] = function (id, _)
    rednet.send(id, { code = "PONG" }, PROTOCOL)
  end,
  ["CLIENT"] = function (id, _)
    local file = fs.open("/disk/storageClient/storageClient.lua", "r")
    if file == nil then
      error("/disk/storageClient.lua isn't accessible")
      rednet.send(id, { code = "ERROR", error = "Unable to send the client program" })
    end
    local data = file.readAll()
    file.close()

    rednet.send(id, { code = "CLIENT_DATA", data = data }, PROTOCOL)
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

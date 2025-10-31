-- config
CONFIG = {
  invManagerChestName = "quark:variant_chest_0"
}

-- global variables unrelated to UI
GLB = {
  -- list of wrapped storage peripherals
  storage = {},
  invManagerChest = {},
  modem = {},
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
    if p ~= CONFIG.invManagerChestName and type == "inventory" then
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
  os.setComputerLabel("StorageMaster")
  rednet.open(peripheral.getName(GLB.modem))
  rednet.host("storage", "main")
end

local function init()
  term.clear()
  term.setCursorPos(1, 1)
  print("initializing...")

  GLB.storage = collectStorage()
  GLB.invManagerChest = peripheral.wrap(CONFIG.invManagerChestName)
  print("collected " .. #GLB.storage .. " containers")

  GLB.modem = findWirelessModem()
  setupRedNetServer()
  print("set up wireless communication")
end

init()

MESSAGE_SWITCH = {
  ["PING"] = function (id, _)
    rednet.send(id, { code = "PONG" }, "storage")
  end,
  ["CLIENT"] = function (id, _)
    local file = fs.open("/disk/storageClient.lua", "r")
    if file == nil then
      error("/disk/storageClient.lua isn't accessible")
      rednet.send(id, { code = "ERROR", error = "Unable to send the client program" })
    end
    local data = file.readAll()
    file.close()

    rednet.send(id, { code = "CLIENT_DATA", data = data }, "storage")
  end
}

while true do
  local id, msg = rednet.receive("storage")

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

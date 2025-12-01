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

settings.define("crafter.encodingBarrel", {
  description = "Barrel peripheral used for recipe encoding",
  default = "",
  type = "string",
})

settings.define("crafter.encodingCrafter", {
  description = "Crafter peripheral used for recipe encoding",
  default = "back",
  type = "string",
})

settings.define("crafter.craftingBarrel", {
  description = "Barrel peripheral used for crafting",
  default = "front",
  type = "string",
})

settings.define("crafter.modemSide", {
  description = "Modem peripheral side",
  default = "right",
  type = "string",
})

CONFIG = {
  encodingBarrel = settings.get("crafter.encodingBarrel"),
  encodingCrafter = settings.get("crafter.encodingCrafter"),
  craftingBarrel = settings.get("crafter.craftingBarrel"),
  protocol = "craft",
  type = "9x9",
  recipeFile = "recipes.lua",
}

GLB = {
  dnsId = 0,
  server = 0,
  encodingBarrel = nil,
  encodingCrafter = nil,
  craftingBarrel = nil,
  ---@type {name: string, ingredients: {name: string, count: number}[], output: {name: string, count: number}}[]
  recipes = {},
}

local function checkConfig()
  local conf = CONFIG

  if conf.encodingBarrel == nil or conf.encodingBarrel == "" then
    error("ERROR: please set crafter.encodingBarrel")
  else
    print(" encodingBarrel = " .. conf.encodingBarrel)
  end

  if conf.encodingCrafter == nil or conf.encodingCrafter == "" then
    error("ERROR: please set crafter.encodingCrafter")
  else
    print(" encodingCrafter = " .. conf.encodingCrafter)
  end

  if conf.craftingBarrel == nil or conf.craftingBarrel == "" then
    error("ERROR: please set crafter.craftingBarrel")
  else
    print(" craftingBarrel = " .. conf.craftingBarrel)
  end
end

local function initRednet()
  local modemSide = settings.get("crafter.modemSide")
  local modem = peripheral.wrap(modemSide)

  if modem == nil then
    error("ERROR: please either add a wireless modem or specify it's location with crafter.modemSide")
  end

  assert(modem.isWireless())

  rednet.open(modemSide)
  local label = "crafter" .. os.getComputerID()
  rednet.host(CONFIG.protocol, label)
  print("serving protocol " .. CONFIG.protocol .. " with hostname " .. label)

  print("looking for DNS server")
  local dnsId = nil
  for _ = 1, 5 do
    dnsId = rednet.lookup("dns", "dns")

    if dnsId ~= nil then
      break
    end

    term.write(".")
    sleep(0.1)
  end

  if dnsId == nil then
    error("ERROR: please set up DNS first")
  end

  GLB.dnsId = dnsId

  print("registering as an autocrafter")
  parallel.waitForAll(
    function()
      rednet.send(dnsId, { code = "REGISTER_CRAFTER" }, "dns")
    end,
    function()
      ::start::

      local id, msg = rednet.receive("dns")
      print(DUMP(msg))
      assert(id)
      assert(msg)

      if msg.sType == "lookup" then
        goto start
      end

      if msg.code ~= "REGISTER_SUCCESS" then
        error("couldn't register in DNS")
        os.exit(69)
      end
    end
  )
  print("registration successful")

  print("looking for the main server")
  for _ = 1, 5 do
    local server = rednet.lookup("storage", "main")

    if server ~= nil then
      GLB.server = server
      break
    end

    term.write(".")
    sleep(0.1)
  end
  if GLB.server == nil then
    error("Please set the server up first")
    os.exit(69)
  end

  print("got main server:", GLB.server)
end

local function initPeripherals()
  GLB.craftingBarrel = peripheral.wrap(CONFIG.craftingBarrel)
  assert(GLB.craftingBarrel)

  GLB.encodingBarrel = peripheral.wrap(CONFIG.encodingBarrel)
  assert(GLB.encodingBarrel)

  GLB.encodingCrafter = peripheral.wrap(CONFIG.encodingCrafter)
  assert(GLB.encodingCrafter)
end

local function loadRecipes()
  GLB.recipes = {}

  local f = fs.open(CONFIG.recipeFile, "r")
  if f == nil then
    return
  end

  local content = f:readAll()
  if content == nil or content == "" then
    return
  end

  GLB.recipes = textutils.unserialise(content)
  f:close()
end

local function init()
  print("initializing...")

  print("checking config...")
  checkConfig()

  print("initializing peripherals..")
  initPeripherals()

  print("initializing rednet communication...")
  initRednet()

  print("loading recipes...")
  loadRecipes()
  print("found " .. #GLB.recipes .. " recipes")
end

init()

---@param recipe {name: string, ingredients: {name: string, count: number}[], output: {name: string, count: number}}
local function saveRecipe(recipe)
  GLB.recipes[#GLB.recipes + 1] = recipe
  local data = textutils.serialise(GLB.recipes)

  local f = fs.open(CONFIG.recipeFile, "w")
  assert(f)

  f.write(data)
  f:close()
end


local function tableLength(tbl)
  local n = 0
  for _ in pairs(tbl) do
    n = n + 1
  end
  return n
end

local function registerRecipe()
  local ingredients = GLB.encodingCrafter.list()

  if tableLength(ingredients) == 0 then
    return
  end

  print("trying to encode a recipe")

  redstone.setOutput(CONFIG.encodingCrafter, true)
  os.sleep(0)
  redstone.setOutput(CONFIG.encodingCrafter, false)

  local result = GLB.encodingBarrel.getItemDetail(1)

  if result == nil then
    print("invalid recipe")
    return
  end

  print("got a recipe for '" .. result.displayName .. "'")

  local alreadyExists = false
  for i = 1, #GLB.recipes do
    if GLB.recipes[i].name == result.displayName then
      alreadyExists = true
      break
    end
  end

  if alreadyExists then
    print("recipe already exists")
    return
  end

  rednet.send(GLB.server, { code = "PUSH_INTO_STORAGE", peripheral = CONFIG.encodingBarrel }, "storage")

  saveRecipe({
    name = result.displayName,
    ingredients = ingredients,
    output = {
      name = result.name,
      count = result.count,
    },
  })
end

MESSAGE_SWITCH = {
  ["GET_INFO"] = function(id, _)
    local recipeNames = {}

    local recipes = GLB.recipes
    for i = 1, #recipes do
      recipeNames[#recipeNames + 1] = recipes[i].name
    end

    rednet.send(id, {
      code = "INFO",
      data = {
        type = "9x9",
        recipes = recipeNames,
      },
    }, CONFIG.protocol)
  end
}

print("listening for events..")
while true do
  local event = { os.pullEvent() }
  assert(event)

  if event[1] == "redstone" then
    registerRecipe()
  elseif event[1] == "rednet_message" then
    local id = event[2]
    assert(id)

    local msg = event[3]

    local protocol = event[4]
    if protocol ~= CONFIG.protocol then
      goto continue
    end

    if msg ~= nil and MESSAGE_SWITCH[msg.code] ~= nil then
      print("received message", msg.code, "from", id)
      MESSAGE_SWITCH[msg.code](id, msg)
    else
      print("unsupported message " .. DUMP(msg))
    end
  end

  ::continue::
end

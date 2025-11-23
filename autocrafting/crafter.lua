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
  encodingBarrel = nil,
  encodingCrafter = nil,
  craftingBarrel = nil,
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

local function registerRecipe()
  local ingredients = GLB.encodingCrafter.list()

  if #ingredients == 0 then
    return
  end

  print("trying to encode a recipe")

  redstone.setOutput(CONFIG.encodingCrafter, true)
  os.sleep(0)
  redstone.setOutput(CONFIG.encodingCrafter, false)

  local result = GLB.encodingBarrel.getItemDetail(1)
  assert(result)
  print(DUMP(result))

  print("got a recipe for '" .. result.displayName .. "'")
  saveRecipe({
    name = result.displayName,
    ingredients = ingredients,
    output = {
      name = result.name,
      count = result.count,
    },
  })
end

parallel.waitForAll(
  function()
    while true do
      os.pullEvent("redstone")
      registerRecipe()
    end
  end,
  function()
    local config = CONFIG
    while true do
      local id, msg = rednet.receive(config.protocol)
      assert(id)
      assert(msg)

      -- TODO
    end
  end
)

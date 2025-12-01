PROTOCOL = "dns"
MODEM = nil

CACHE_SERVER_COUNT = 60
DRAWER_CACHE_SERVER_COUNT = 1
AUTOCRAFTERS_COUNT = 1

PERIPHERAL_NAMES = {
  ["inventory manager buffer"] = "quark:variant_chest_1",
  ["inventory manager"] = "inventoryManager_1",
  ["main storage"] = {
    "create_connected:item_silo_1",
    "create_connected:item_silo_0",
  },
  ["drawer storage"] = {
    { name = "functionalstorage:oak_2_0",                    filter = { "minecraft:stone", "minecraft:cobblestone" } },
    { name = "functionalstorage:oak_1_1",                    filter = { "minecraft:barrel" } },
    { name = "functionalstorage:oak_1_3",                    filter = { "minecraft:andesite" } },
    { name = "functionalstorage:oak_4_0",                    filter = { "minecraft:oak_log", "minecraft:apple", "minecraft:stick", "minecraft:oak_sapling" } },
    { name = "functionalstorage:oak_1_5",                    filter = { "minecraft:kelp" } },
    { name = "functionalstorage:oak_1_9",                    filter = { "minecraft:bamboo" } },
    { name = "functionalstorage:oak_1_10",                   filter = { "kubejs:kinetic_mechanism" } },
    { name = "functionalstorage:oak_1_11",                   filter = { "kubejs:precision_mechanism" } },
    { name = "functionalstorage:oak_1_17",                   filter = { "kubejs:inductive_mechanism" } },
    { name = "functionalstorage:simple_compacting_drawer_0", filter = { "ae2:fluix_crystal", "ae2:fluix_block" } },
    { name = "functionalstorage:oak_1_13",                   filter = { "create:andesite_alloy" } },
    { name = "functionalstorage:oak_1_14",                   filter = { "minecraft:sugar_cane" } },
    { name = "functionalstorage:oak_1_15",                   filter = { "minecraft:gunpowder" } },
    { name = "functionalstorage:oak_1_16",                   filter = { "thermal:silver_coin" } },
    {
      name = "functionalstorage:storage_controller_0",
      separateCache = true,
      filter = {
        "tconstruct:amethyst_bronze_nugget",
        "tconstruct:amethyst_bronze_ingot",
        "tconstruct:amethyst_bronze_block",
        "create:zinc_nugget",
        "create:zinc_ingot",
        "create:zinc_block",
        "thermal:nickel_nugget",
        "thermal:nickel_ingot",
        "thermal:nickel_block",
        "ad_astra:steel_nugget",
        "ad_astra:steel_ingot",
        "ad_astra:steel_block",
        "minecraft:diamond",
        "minecraft:diamond_block",
        "thermal:lumium_nugget",
        "thermal:lumium_ingot",
        "thermal:lumium_block",
        "minecraft:copper_ingot",
        "minecraft:copper_block",
        "thermal:signalum_nugget",
        "thermal:signalum_ingot",
        "thermal:signalum_block",
        "minecraft:iron_nugget",
        "minecraft:iron_ingot",
        "minecraft:iron_block",
        "thermal:bronze_nugget",
        "thermal:bronze_ingot",
        "thermal:bronze_block",
        "create:brass_nugget",
        "create:brass_ingot",
        "create:brass_block",
        "tconstruct:cobalt_nugget",
        "tconstruct:cobalt_ingot",
        "tconstruct:cobalt_block",
        "thermal:lead_nugget",
        "thermal:lead_ingot",
        "thermal:lead_block",
        "minecraft:glowstone_dust",
        "minecraft:glowstone",
        "minecraft:gold_nugget",
        "minecraft:gold_ingot",
        "minecraft:gold_block",
        "minecraft:coal",
        "minecraft:coal_block",
        "thermal:constantan_nugget",
        "thermal:constantan_ingot",
        "thermal:constantan_block",
        "minecraft:obsidian",
        "minecraft:emerald",
        "minecraft:emerald_block",
        "minecraft:quartz",
        "minecraft:quartz_block",
        "minecraft:redstone",
        "minecraft:redstone_block",
        "occultism:otherstone",
        "minecraft:lapis_lazuli",
        "minecraft:lapis_block",
        "ae2:sky_stone_block",
      }
    }
  },
  ["chat box"] = "chatBox_0",
  ["cache servers"] = {},
  ["drawer cache servers"] = {},
  ["autocrafters"] = {},
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

local function setupRednet()
  MODEM = peripheral.find("modem", function(_, m) return m.isWireless() end)

  os.setComputerLabel("DNS Server")
  rednet.open(peripheral.getName(MODEM))
  rednet.host(PROTOCOL, "dns")
end

local function init()
  print("initializing...")

  term.write("setting up rednet...")
  setupRednet()
  print("done")

  print("available peripherals: ")
  for alias, name in pairs(PERIPHERAL_NAMES) do
    print("  " .. alias .. ": " .. DUMP(name))
  end
end

init()

while true do
  local id, msg = rednet.receive("dns")
  assert(id)
  if msg == nil then
    rednet.send(id, "UNKNOWN", "dns")
    print(id, DUMP(msg), "UNKNOWN")
  elseif msg.code == "REGISTER_CRAFTER" then
    rednet.send(id, { code = "REGISTER_SUCCESS" }, "dns")
    local registeredAlready = false
    for i = 1, #PERIPHERAL_NAMES["autocrafters"] do
      if PERIPHERAL_NAMES["autocrafters"][i] == id then
        registeredAlready = true
        break
      end
    end

    if not registeredAlready then
      table.insert(PERIPHERAL_NAMES["autocrafters"], id)
    end
    print("registered an autocrafter:", id)
  elseif msg.code == "REGISTER_CACHE" then
    rednet.send(id, { code = "REGISTER_SUCCESS" }, "dns")
    local registeredAlready = false
    for i = 1, #PERIPHERAL_NAMES["cache servers"] do
      if PERIPHERAL_NAMES["cache servers"][i] == id then
        registeredAlready = true
        break
      end
    end

    if not registeredAlready then
      table.insert(PERIPHERAL_NAMES["cache servers"], id)
    end
    print("registered a cache server:", id)
  elseif msg.code == "REGISTER_CACHE_DRAWER" then
    rednet.send(id, { code = "REGISTER_SUCCESS" }, "dns")
    local registeredAlready = false
    for i = 1, #PERIPHERAL_NAMES["drawer cache servers"] do
      if PERIPHERAL_NAMES["drawer cache servers"][i] == id then
        registeredAlready = true
        break
      end
    end

    if not registeredAlready then
      table.insert(PERIPHERAL_NAMES["drawer cache servers"], id)
    end
    print("registered a drawer cache server:", id)
  elseif msg == "cache servers" then
    local servers = PERIPHERAL_NAMES["cache servers"]
    if #servers < CACHE_SERVER_COUNT then
      rednet.send(id, { code = "WAITABIT" }, "dns")
    else
      rednet.send(id, { code = "CACHE_SERVERS", data = servers }, "dns")
    end
  elseif msg == "autocrafters" then
    local servers = PERIPHERAL_NAMES["autocrafters"]
    if #servers < AUTOCRAFTERS_COUNT then
      rednet.send(id, { code = "WAITABIT" }, "dns")
    else
      rednet.send(id, { code = "AUTOCRAFTERS", data = servers }, "dns")
    end
  elseif msg == "drawer cache servers" then
    local servers = PERIPHERAL_NAMES["drawer cache servers"]
    if #servers < DRAWER_CACHE_SERVER_COUNT then
      rednet.send(id, { code = "WAITABIT" }, "dns")
    else
      rednet.send(id, { code = "DRAWER_CACHE_SERVERS", data = servers }, "dns")
    end
  elseif msg.sType ~= "lookup" then
    rednet.send(id, PERIPHERAL_NAMES[msg], "dns")
    print(id, DUMP(msg), DUMP(PERIPHERAL_NAMES[msg]))
  end
end

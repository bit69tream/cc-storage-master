PROTOCOL = "dns"
MODEM = nil

PERIPHERAL_NAMES = {
  ["inventory manager buffer"] = "quark:variant_chest_1",
  ["inventory manager"] = "inventoryManager_1",
  ["main storage"] = {
    "create_connected:item_silo_1",
    "create_connected:item_silo_0",
  },
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
  MODEM = peripheral.find("modem", function (_, m) return m.isWireless() end)

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
  elseif msg.sType ~= "lookup" then
    rednet.send(id, PERIPHERAL_NAMES[msg], "dns")
    print(id, DUMP(msg), DUMP(PERIPHERAL_NAMES[msg]))
  end
end

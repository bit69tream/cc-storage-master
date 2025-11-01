PROTOCOL = "dns"
MODEM = nil

PERIPHERAL_NAMES = {
  ["storage turtle"] = "turtle_1",
  ["inventory manager buffer"] = "quark:variant_chest_0",
  ["inventory manager"] = "inventoryManager_0",
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

local function setupRednet()
  MODEM = findWirelessModem()

  os.setComputerLabel("DNS Server")
  rednet.open(peripheral.getName(MODEM))
  rednet.host(PROTOCOL, "dns")
end

local function init()
  print("initializing...")

  print("setting up rednet")
  setupRednet()

  print("available peripherals: ")
  for alias, name in pairs(PERIPHERAL_NAMES) do
    print("  " .. alias .. ": " .. name)
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
    print(id, DUMP(msg), PERIPHERAL_NAMES[msg])
  end
end

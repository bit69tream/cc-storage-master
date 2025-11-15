PROTOCOL = "cache"
MODEM_SIDE = "front"

print("initializing...")
local label = "drawerCache" .. os.getComputerID()
os.setComputerLabel(label)

print("setting up wireless communication...")
rednet.open(MODEM_SIDE)

rednet.host("cache", label)

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

local dnsId = nil
print("looking for DNS server")
for _ = 1, 5 do
  dnsId = rednet.lookup("dns", "dns")

  if dnsId ~= nil then
    break
  end

  term.write(".")
  sleep(0.1)
end

if dnsId == nil then
  error("please set up DNS server first")
  os.exit(69)
end

print("found DNS server:", dnsId)

print("registering as a drawer cache server")
parallel.waitForAll(
  function()
    rednet.send(dnsId, { code = "REGISTER_CACHE_DRAWER" }, "dns")
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

---@type {getItemDetail: function }
STORAGE_PERIPHERALS = {}
ITEMS = {}

parallel.waitForAll(
  function()
    while true do
      local id, msg = rednet.receive("cache")
      assert(id)
      assert(msg)

      if msg.code == "SETUP" then
        local peripherals = {}
        for i = 1, #msg.data do
          peripherals[#peripherals + 1] = peripheral.wrap(msg.data[i])
        end
        STORAGE_PERIPHERALS = peripherals
        print("assigned", DUMP(msg.data))
      elseif msg.code == "GET_ITEMS" then
        rednet.send(id, { code = "ITEMS_LIST", data = ITEMS }, "cache")
      end
    end
  end,
  function()
    while true do
      local newItems = {}
      local peripherals = STORAGE_PERIPHERALS

      if #peripherals == 0 then
        goto continue
      end

      for p = 1, #peripherals do
        local prph = peripheral.getName(peripherals[p])
        for i = 1, peripherals[p].size() do
          local details = peripherals[p].getItemDetail(i)
          if details ~= nil then
            details.peripheral = prph
            details.slot = i
            newItems[#newItems + 1] = details
          end
        end
      end

      ITEMS = newItems

      ::continue::
      sleep(2)
    end
  end
)

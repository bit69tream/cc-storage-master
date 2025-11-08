PROTOCOL = "cache"
MODEM_SIDE = "front"

print("initializing...")
local label = "cache" .. os.getComputerID()
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

print("registering as a cache server")
parallel.waitForAll(
  function()
    rednet.send(dnsId, { code = "REGISTER_CACHE" }, "dns")
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
STORAGE_PERIPHERAL = {}
RANGE = { from = 0, upto = 0 }
ITEMS = {}
EMPTY_SLOTS = {}

parallel.waitForAll(
  function()
    while true do
      local id, msg = rednet.receive("cache")
      assert(id)
      assert(msg)

      if msg.code == "SETUP" then
        STORAGE_PERIPHERAL = peripheral.wrap(msg.peripheral)
        RANGE = msg.range
        print("assigned", msg.peripheral, "from", msg.range.from, "up to", msg.range.upto)
      elseif msg.code == "GET_ITEMS" then
        rednet.send(id, { code = "ITEMS_LIST", data = ITEMS }, "cache")
      elseif msg.code == "GET_EMPTY_SLOTS" then
        rednet.send(id,
          {
            code = "EMPTY_SLOTS",
            data = EMPTY_SLOTS,
            peripheral = peripheral.getName(STORAGE_PERIPHERAL)
          },
          "cache")
      end
    end
  end,
  function()
    while true do
      local newItems = {}
      local emptySlots = {}
      local prph = ""

      if STORAGE_PERIPHERAL.getItemDetail == nil then
        goto continue
      end

      prph = peripheral.getName(STORAGE_PERIPHERAL)
      for i = RANGE.from, RANGE.upto do
        local details = STORAGE_PERIPHERAL.getItemDetail(i)
        if details == nil then
          emptySlots[#emptySlots + 1] = i
        else
          details.peripheral = prph
          newItems[#newItems + 1] = details
        end
      end

      ITEMS = newItems

      ::continue::
      sleep(2)
    end
  end
)

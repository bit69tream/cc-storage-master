local config = {
  {
    fromPeripheral = peripheral.wrap("functionalstorage:oak_4_0"),
    toPeripheral = peripheral.wrap("functionalstorage:oak_1_4"),
    name = "minecraft:stick",
  },
  {
    fromPeripheral = peripheral.wrap("functionalstorage:oak_1_5"),
    toPeripheral = peripheral.wrap("functionalstorage:oak_1_6"),
    name = "minecraft:kelp",
  },
  {
    fromPeripheral = peripheral.wrap("functionalstorage:oak_1_3"),
    toPeripheral = peripheral.wrap("functionalstorage:oak_1_7"),
    name = "minecraft:andesite",
  },
  {
    fromPeripheral = peripheral.wrap("functionalstorage:oak_4_0"),
    toPeripheral = peripheral.wrap("functionalstorage:oak_1_8"),
    name = "minecraft:oak_log",
  },
}

for i = 1, #config do
  print("stocking",
    config[i].name,
    "from",
    peripheral.getName(config[i].fromPeripheral),
    "to",
    peripheral.getName(config[i].toPeripheral))
end

print("started")

while true do
  for i = 1, #config do
    local from = config[i].fromPeripheral
    assert(from)

    for k, v in pairs(from.list()) do
      if v.name == config[i].name then
        from.pushItems(peripheral.getName(config[i].toPeripheral), k)
        break
      end
    end
  end

  sleep(2)
end

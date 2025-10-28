-- global variables unrelated to UI
GLB = {
  -- list of wrapped storage peripherals
  storage = {},
}

-- global variables related to UI
UISTATE = {

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

local function collectStorage()
  local periheralList = peripheral.getNames()
  local storage = {}

  for i = 1, #periheralList do
    local p = periheralList[i]
    local _, type = peripheral.getType(p)
    if type == "inventory" then
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

local function init()
  term.clear()
  term.setCursorPos(1, 1)
  term.write("initializing")

  GLB.storage = collectStorage()
  term.write(".")
  term.setCursorPos(1, 2)
end

init()

print(DUMP(GLB.storage))

local amog = getItemList()

for i = 1, #amog do
  if amog[i].name == "minecraft:basalt" then
    print(amog[i].count)
  end
end

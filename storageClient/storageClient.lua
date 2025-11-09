MODEM_PERIPHERAL = "back"
PROTOCOL = "storage"

GLB = {
  modem = nil,
  server = nil,
}

WINDOW_BOUNDS = {
  yStart = 5,
  yEnd = -2
}

-- ui state
UI = {
  term = {},
  focusedId = 1,
  tabs = {
    tabActiveId = 1,
    y = 4,
    storage = {
      id = 1,
      name = "",
      xStart = 0,
      xEnd = 0,
      window = {},
      scroll = 0,
      ---@type {name: string, count: number, slot: number, displayName: string, nbt: string, peripheral: string }[]
      inventory = {},
      ---@type {name: string, count: number, slot: number, displayName: string, nbt: string, peripheral: string }[]
      filteredInventory = {},
      focusedItem = 0,
    },
    player = {
      id = 2,
      name = "",
      xStart = 0,
      xEnd = 0,
      window = {},
      scroll = 0,
      ---@type {name: string, count: number, slot: number, displayName: string, nbt: string }[]
      inventory = {},
      ---@type {name: string, count: number, slot: number, displayName: string, nbt: string }[]
      filteredInventory = {},
      focusedItem = 0,
    },
  },
  searchBar = {
    id = 3,
    y = 3,
    prompt = "> ",
    query = "",
  },
  controls = {
    yStart = -1,
    yEnd = 0,
    pressedButtonId = 0,
    amount = {
      n = 64,
      y = 0,
      xStart = 9,
      xEnd = -12,
    },
    buttons = {
      storage = {
        id = 4,
        text = " Get ",
        xStart = 2,
        xEnd = 6,
        y = 0,
      },
      player = {
        id = 5,
        text = " Send ",
        xStart = 2,
        xEnd = 7,
        y = 0,
      },
      minus64 = {
        id = 6,
        text = "-64",
        xStart = -3,
        xEnd = -1,
        y = -1,
      },
      minus32 = {
        id = 7,
        text = "-32",
        xStart = -7,
        xEnd = -5,
        y = -1,
      },
      minus1 = {
        id = 8,
        text = "-1",
        xStart = -10,
        xEnd = -8,
        y = -1,
      },
      plus1 = {
        id = 9,
        text = "+1",
        xStart = -10,
        xEnd = -8,
        y = 0,
      },
      plus32 = {
        id = 10,
        text = "+32",
        xStart = -7,
        xEnd = -5,
        y = 0,
      },
      plus64 = {
        id = 11,
        text = "+64",
        xStart = -3,
        xEnd = -1,
        y = 0,
      },
    },
  }
}

local function checkServer()
  term.write("checking server....")

  parallel.waitForAll(function()
      rednet.send(GLB.server, { code = "PING" }, PROTOCOL)
    end,
    function()
      local id, msg = rednet.receive(PROTOCOL, 2)

      if id == nil or msg == nil then
        error("The server isn't running")
        os.exit(69)
      end

      if msg.code ~= "PONG" then
        error("The server isn't set up correctly")
        os.exit(69)
      end

      print("the server is running correctly")
    end)
end

local function setupRednetClient()
  GLB.modem = peripheral.wrap(MODEM_PERIPHERAL)
  os.setComputerLabel("Storage Client")
  rednet.open(MODEM_PERIPHERAL)

  term.write("looking for the main server")
  for _ = 1, 5 do
    local server = rednet.lookup(PROTOCOL, "main")

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
end

W = nil
H = nil

local function centerString(line, width)
  local pad = width - #line
  local left = math.floor(pad / 2)
  local right = pad - left

  return string.rep(" ", left) .. line .. string.rep(" ", right)
end

local function initUI()
  term.clear()

  W, H = term.getSize()

  if W < 26 or H < 20 then
    error("The portable terminal needs to be at least 26x20")
    os.exit(69)
  end

  WINDOW_BOUNDS.yEnd = H + WINDOW_BOUNDS.yEnd

  local line1 = "Storage"
  local line2 = "Master"

  local line1x = math.floor((W / 2) - (#line1 / 2))
  term.setCursorPos(line1x, 1)
  term.write(line1)

  local line2x = math.floor((W / 2) - (#line2 / 2))
  term.setCursorPos(line2x, 2)
  term.write(line2)

  local hw = math.floor(W / 2)
  UI.tabs.storage.xStart = 2
  UI.tabs.storage.xEnd = hw
  UI.tabs.player.xStart = hw + 1
  UI.tabs.player.xEnd = W

  local tabStorageWidth = UI.tabs.storage.xEnd - UI.tabs.storage.xStart
  local tabPlayerWidth = UI.tabs.player.xEnd - UI.tabs.player.xStart

  UI.tabs.storage.name = centerString("storage", tabStorageWidth)
  UI.tabs.player.name = centerString("player", tabPlayerWidth)

  UI.term = term.current()

  UI.tabs.storage.window = window.create(term.current(), 1, WINDOW_BOUNDS.yStart, W,
    WINDOW_BOUNDS.yEnd - WINDOW_BOUNDS.yStart + 1, false)
  UI.tabs.player.window = window.create(term.current(), 1, WINDOW_BOUNDS.yStart, W,
    WINDOW_BOUNDS.yEnd - WINDOW_BOUNDS.yStart + 1, false)

  UI.controls.yEnd = H + UI.controls.yEnd
  UI.controls.yStart = H + UI.controls.yStart

  UI.controls.amount.xEnd = UI.controls.amount.xEnd + W
  UI.controls.amount.y = UI.controls.amount.y + H

  for k, v in pairs(UI.controls.buttons) do
    UI.controls.buttons[k].y = H + v.y
    if v.xStart >= 1 then
      goto continue
    end

    UI.controls.buttons[k].xStart = W + v.xStart
    UI.controls.buttons[k].xEnd = W + v.xEnd

    ::continue::
  end
end

local function init()
  print("initializing...")

  setupRednetClient()
  print("configured wireless connection")

  checkServer()

  initUI()
end

TAB_ACTIVE_BG = "0"
TAB_ACTIVE_FG = "7"
TAB_INACTIVE_BG = "7"
TAB_INACTIVE_FG = "0"

local function renderTabNames()
  term.setCursorPos(1, UI.tabs.y)
  term.clearLine()

  local storageTabFg = TAB_INACTIVE_FG
  local storageTabBg = TAB_INACTIVE_BG
  local playerTabFg = TAB_INACTIVE_FG
  local playerTabBg = TAB_INACTIVE_BG
  if UI.tabs.tabActiveId == UI.tabs.storage.id then
    storageTabBg = TAB_ACTIVE_BG
    storageTabFg = TAB_ACTIVE_FG
  elseif UI.tabs.tabActiveId == UI.tabs.player.id then
    playerTabBg = TAB_ACTIVE_BG
    playerTabFg = TAB_ACTIVE_FG
  else
    error("one of the tabs must be focused")
  end

  term.setCursorPos(UI.tabs.storage.xStart, UI.tabs.y)
  term.blit(
    UI.tabs.storage.name,
    string.rep(storageTabFg, #UI.tabs.storage.name),
    string.rep(storageTabBg, #UI.tabs.storage.name))

  term.setCursorPos(UI.tabs.player.xStart, UI.tabs.y)
  term.blit(
    UI.tabs.player.name,
    string.rep(playerTabFg, #UI.tabs.player.name),
    string.rep(playerTabBg, #UI.tabs.player.name))
end

local function fetchPlayerInventory()
  parallel.waitForAll(
    function()
      rednet.send(GLB.server, { code = "GET_PLAYER_INV" }, PROTOCOL)
    end,
    function()
      local id, data = rednet.receive(PROTOCOL)
      assert(id == GLB.server)
      if data ~= nil and data.code == "PLAYER_INVENTORY" then
        UI.tabs.player.inventory = data.data
      end
    end
  )
end

local function fetchStorage()
  parallel.waitForAll(
    function()
      rednet.send(GLB.server, { code = "GET_STORAGE" }, PROTOCOL)
    end,
    function()
      local id, msg = rednet.receive(PROTOCOL)
      assert(id == GLB.server)
      assert(msg)
      assert(msg.code == "STORAGE")
      local items = msg.data
      table.sort(items, function(a, b) return a.displayName < b.displayName end)
      UI.tabs.storage.inventory = items
    end
  )
end

---@param tab string
local function renderTab(tab)
  term.redirect(UI.tabs[tab].window)

  UI.tabs[tab].filteredInventory = {}
  if UI.searchBar.query == "" then
    UI.tabs[tab].filteredInventory = UI.tabs[tab].inventory
  else
    local q = string.lower(UI.searchBar.query)
    for i = 1, #UI.tabs[tab].inventory do
      if string.find(string.lower(UI.tabs[tab].inventory[i].displayName), q) ~= nil then
        UI.tabs[tab].filteredInventory[#UI.tabs[tab].filteredInventory + 1] = UI.tabs[tab].inventory[i]
      end
    end
  end

  term.clear()
  for i = 1 + UI.tabs[tab].scroll, #UI.tabs[tab].filteredInventory do
    if i == UI.tabs[tab].focusedItem then
      term.setTextColor(colors.black)
      term.setBackgroundColor(colors.white)
    else
      term.setTextColor(colors.lightGray)
      term.setBackgroundColor(colors.black)
    end
    term.setCursorPos(1, i - UI.tabs[tab].scroll)
    term.write(UI.tabs[tab].filteredInventory[i].count .. " " .. UI.tabs[tab].filteredInventory[i].displayName)
  end

  term.redirect(UI.term)
end

local function renderTabs()
  renderTabNames()

  local tab = nil
  tab = "storage"
  if UI.tabs.player.id == UI.tabs.tabActiveId then
    tab = "player"
  elseif UI.tabs.storage.id == UI.tabs.tabActiveId then
    tab = "storage"
  end

  renderTab(tab)
end

QUERY_INACTIVE_FG = "8"
QUERY_INACTIVE_BG = "f"

QUERY_ACTIVE_FG = "0"
QUERY_ACTIVE_BG = "f"

local function renderSearchBar()
  term.setCursorPos(1, UI.searchBar.y)
  term.clearLine()

  local queryFg = QUERY_INACTIVE_FG
  local queryBg = QUERY_INACTIVE_BG

  if UI.focusedId == UI.searchBar.id then
    queryBg = QUERY_ACTIVE_BG
    queryFg = QUERY_ACTIVE_FG
  end

  local promptLen = #UI.searchBar.prompt
  local queryLen = #UI.searchBar.query
  local line = UI.searchBar.prompt .. UI.searchBar.query

  term.blit(
    line,
    string.rep("0", promptLen) .. string.rep(queryFg, queryLen),
    string.rep("f", promptLen) .. string.rep(queryBg, queryLen))
end

local function setCursorFocusedLocation()
  if UI.focusedId == UI.searchBar.id then
    local lineLen = #UI.searchBar.prompt + #UI.searchBar.query
    term.setCursorPos(lineLen + 1, UI.searchBar.y)
    term.setCursorBlink(true)
  end
end

BUTTON_PRESSED_BG = "0"
BUTTON_PRESSED_FG = "7"
BUTTON_UNPRESSED_BG = "7"
BUTTON_UNPRESSED_FG = "0"
local function renderControls()
  for yi = UI.controls.yStart, UI.controls.yEnd do
    term.setCursorPos(1, yi)
    term.clearLine()
  end

  local amountMaxLen = UI.controls.amount.xEnd - UI.controls.amount.xStart + 1
  local amountStr = tostring(UI.controls.amount.n)
  local amountLen = #amountStr

  local amountRenderStr = string.rep("0", amountMaxLen - amountLen) .. amountStr

  term.setCursorPos(UI.controls.amount.xStart, UI.controls.amount.y)
  term.blit(
    amountRenderStr,
    string.rep("0", #amountRenderStr),
    string.rep("f", #amountRenderStr))

  ---@type {id: number, text: string, xStart: number, xEnd: number, y: number}
  local tabButton = {}

  if UI.tabs.tabActiveId == UI.tabs.player.id then
    tabButton = UI.controls.buttons.player
  elseif UI.tabs.tabActiveId == UI.tabs.storage.id then
    tabButton = UI.controls.buttons.storage
  end

  ---@param btn {id: number, text: string, xStart: number, xEnd: number, y: number}
  local function renderButton(btn)
    local fg = BUTTON_UNPRESSED_FG
    local bg = BUTTON_UNPRESSED_BG
    if btn.id == UI.controls.pressedButtonId then
      fg = BUTTON_PRESSED_FG
      bg = BUTTON_PRESSED_BG
    end

    term.setCursorPos(btn.xStart, btn.y)
    term.blit(
      btn.text,
      string.rep(fg, #btn.text),
      string.rep(bg, #btn.text))
  end

  renderButton(tabButton)

  for k, v in pairs(UI.controls.buttons) do
    if k == "storage" or k == "player" then
      goto continue
    end

    renderButton(v)

    ::continue::
  end

  UI.controls.pressedButtonId = 0
end

local function renderUI()
  term.setCursorBlink(false)

  renderTabs()
  renderSearchBar()
  renderControls()

  setCursorFocusedLocation()
end

---@param n number
---@param min number
---@param max number
---@return number
local function clamp(n, min, max)
  return math.min(max, math.max(n, min))
end

local function requestItemFromStorage()
  local st = UI.tabs.storage

  if st.focusedItem == 0 then
    return
  end

  local item = st.filteredInventory[st.focusedItem]

  rednet.send(GLB.server,
    {
      code = "REQUEST_ITEM",
      data = {
        count = UI.controls.amount.n,
        name = item.name,
        peripheral = item.peripheral,
        nbt = item.nbt,
      }
    },
    "storage")
end

local function sendItemFromInv()
  local pl = UI.tabs.player
  if pl.focusedItem == 0 then
    return
  end

  local item = pl.filteredInventory[pl.focusedItem]

  rednet.send(GLB.server,
    {
      code = "SEND_FROM_INV",
      data = {
        slot = item.slot,
        count = math.min(UI.controls.amount.n, item.count),
        name = item.name,
      }
    },
    "storage")
end

local function processMouseClick(x, y, button)
  _ = button

  UI.focusedId = 0

  -- check if tabs were clicked
  if y == UI.tabs.y then
    UI.controls.amount.n = 64
    if x >= UI.tabs.storage.xStart and x < UI.tabs.storage.xEnd then
      UI.tabs.tabActiveId = UI.tabs.storage.id
      UI.focusedId = UI.tabs.storage.id

      UI.tabs.storage.window.setVisible(true)
      UI.tabs.player.window.setVisible(false)
    elseif x >= UI.tabs.player.xStart and x < UI.tabs.player.xEnd then
      UI.tabs.tabActiveId = UI.tabs.player.id
      UI.focusedId = UI.tabs.player.id

      UI.tabs.storage.window.setVisible(false)
      UI.tabs.player.window.setVisible(true)
    end

    return
  end

  if y >= WINDOW_BOUNDS.yStart and y <= WINDOW_BOUNDS.yEnd then
    if UI.tabs.tabActiveId == UI.tabs.player.id then
      UI.tabs.player.focusedItem = y - WINDOW_BOUNDS.yStart + 1 + UI.tabs.player.scroll
      renderTab("player")
    elseif UI.tabs.tabActiveId == UI.tabs.storage.id then
      UI.tabs.storage.focusedItem = y - WINDOW_BOUNDS.yStart + 1 + UI.tabs.storage.scroll
      renderTab("storage")
    end

    return
  end

  if y == UI.searchBar.y then
    UI.focusedId = UI.searchBar.id

    return
  end

  if y >= UI.controls.yStart and y <= UI.controls.yEnd then
    local invButton = {}
    if UI.tabs.tabActiveId == UI.tabs.player.id then
      invButton = UI.controls.buttons.player
      sendItemFromInv()
    elseif UI.tabs.tabActiveId == UI.tabs.storage.id then
      invButton = UI.controls.buttons.storage
      requestItemFromStorage()
    end

    if y == invButton.y and x >= invButton.xStart and x <= invButton.xEnd then
      UI.controls.pressedButtonId = invButton.id

      return
    end

    for k, v in pairs(UI.controls.buttons) do
      if k == "player" or k == "storage" then
        goto continue
      end

      if y == v.y and x >= v.xStart and x <= v.xEnd then
        UI.controls.pressedButtonId = v.id

        local ndiff = 0
        if k == "minus64" then
          ndiff = -64
        elseif k == "minus32" then
          ndiff = -32
        elseif k == "minus1" then
          ndiff = -1
        elseif k == "plus64" then
          ndiff = 64
        elseif k == "plus32" then
          ndiff = 32
        elseif k == "plus1" then
          ndiff = 1
        end

        local maxItemAmount = 27 * 64

        UI.controls.amount.n = clamp(UI.controls.amount.n + ndiff, 1, maxItemAmount)
        break
      end

      ::continue::
    end

    return
  end
end

local function processChar(c)
  if UI.focusedId == UI.searchBar.id then
    UI.searchBar.query = UI.searchBar.query .. c

    if UI.tabs.tabActiveId == UI.tabs.player.id then
      UI.tabs.player.focusedItem = 0
      UI.tabs.player.scroll = 0
      renderTab("player")
    elseif UI.tabs.tabActiveId == UI.tabs.storage.id then
      UI.tabs.storage.focusedItem = 0
      UI.tabs.storage.scroll = 0
      renderTab("storage")
    end
  end
end

local function processKeyPress(key)
  if UI.focusedId == UI.searchBar.id and key == keys.backspace then
    UI.searchBar.query = string.sub(UI.searchBar.query, 1, -2)

    if UI.tabs.tabActiveId == UI.tabs.player.id then
      UI.tabs.player.focusedItem = 0
      UI.tabs.player.scroll = 0
      renderTab("player")
    elseif UI.tabs.tabActiveId == UI.tabs.storage.id then
      UI.tabs.storage.focusedItem = 0
      UI.tabs.storage.scroll = 0
      renderTab("storage")
    end
  end
end

local function processMouseScroll(dir, _, y)
  if y >= WINDOW_BOUNDS.yStart and y <= WINDOW_BOUNDS.yEnd then
    if UI.tabs.tabActiveId == UI.tabs.player.id then
      UI.tabs.player.scroll = clamp(UI.tabs.player.scroll + dir, 0, 27)
      renderTab("player")
    elseif UI.tabs.tabActiveId == UI.tabs.storage.id then
      UI.tabs.storage.scroll = clamp(UI.tabs.storage.scroll + dir, 0, 4096)
      renderTab("storage")
    end

    return
  end
end

init()

local function mainLoop()
  while true do
    renderUI()

    local eventData = { os.pullEvent() }
    local event = eventData[1]

    if event == "mouse_click" then
      processMouseClick(eventData[3], eventData[4], eventData[2])
    elseif event == "mouse_scroll" then
      processMouseScroll(eventData[2], eventData[3], eventData[4])
    elseif event == "char" then
      processChar(eventData[2])
    elseif event == "key" then
      processKeyPress(eventData[2])
    end
  end
end


parallel.waitForAll(
  function()
    while true do
      fetchPlayerInventory()
      fetchStorage()
      sleep(3)
    end
  end,
  mainLoop
)

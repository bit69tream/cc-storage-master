MODEM_PERIPHERAL = "back"
PROTOCOL = "storage"

GLB = {
  modem = nil,
  server = nil,
}

W, H = term.getSize()

if W < 26 or H < 19 then
  error("The portable terminal needs to be at least 26x19")
  os.exit(69)
end

WINDOW_BOUNDS = {
  yStart = 5,
  yEnd = H - 2
}

IOTA_NUM = 0

---@return number
function IOTA()
  local ret = IOTA_NUM
  IOTA_NUM = IOTA_NUM + 1

  return ret
end

CONTROL_BUTTONS_UP_COLOR = "5"
CONTROL_BUTTONS_DOWN_COLOR = "e"

-- ui state
UI = {
  term = term.current(),
  focusedId = 0,
  tabs = {
    tabActiveId = IOTA_NUM,
    y = 4,
    storage = {
      id = IOTA(),
      name = "storage",
      xStart = 2,
      xEnd = math.floor(W / 2),
      window = window.create(
        term.current(),
        1,
        WINDOW_BOUNDS.yStart,
        W,
        WINDOW_BOUNDS.yEnd - WINDOW_BOUNDS.yStart + 1,
        false),
      scroll = 0,
      ---@type {name: string, count: number, slot: number, displayName: string, nbt: string, peripheral: string }[]
      inventory = {},
      ---@type {name: string, count: number, slot: number, displayName: string, nbt: string, peripheral: string }[]
      filteredInventory = {},
      focusedItem = 0,
    },
    player = {
      id = IOTA(),
      name = "player",
      xStart = math.floor(W / 2) + 1,
      xEnd = W,
      window = window.create(
        term.current(),
        1,
        WINDOW_BOUNDS.yStart,
        W,
        WINDOW_BOUNDS.yEnd - WINDOW_BOUNDS.yStart + 1,
        false),
      scroll = 0,
      ---@type {name: string, count: number, slot: number, displayName: string, nbt: string }[]
      inventory = {},
      ---@type {name: string, count: number, slot: number, displayName: string, nbt: string }[]
      filteredInventory = {},
      focusedItem = 0,
    },
  },
  searchBar = {
    id = IOTA(),
    y = 3,
    prompt = "> ",
    query = "",
  },
  sendRequestControls = {
    yStart = H - 1,
    yEnd = H,
    pressedButtonId = 0,
    amount = {
      n = 64,
      y = H,
      xStart = 11,
      xEnd = W - 12,
    },
    buttons = {
      storage = {
        id = IOTA(),
        text = " Get ",
        x = 2,
        y = H,
        color = "5",
      },
      player = {
        id = IOTA(),
        text = " Send ",
        x = 2,
        y = H,
        color = "1",
      },
      one = {
        id = IOTA(),
        text = "1",
        x = W - 9,
        y = H - 1,
        n = 1,
        color = CONTROL_BUTTONS_UP_COLOR,
      },
      sixteen = {
        id = IOTA(),
        text = "16",
        x = W - 6,
        y = H - 1,
        n = 16,
        color = CONTROL_BUTTONS_UP_COLOR,
      },
      thirtytwo = {
        id = IOTA(),
        text = "32",
        x = W - 2,
        y = H - 1,
        n = 32,
        color = CONTROL_BUTTONS_UP_COLOR,
      },
      sixtyfour = {
        id = IOTA(),
        text = "64",
        x = W - 10,
        y = H,
        n = 64,
        color = CONTROL_BUTTONS_UP_COLOR,
      },
      onetwentyeight = {
        id = IOTA(),
        text = "128",
        x = W - 7,
        y = H,
        n = 128,
        color = CONTROL_BUTTONS_UP_COLOR,
      },
      fivehundredandtwelve = {
        id = IOTA(),
        text = "512",
        x = W - 3,
        y = H,
        n = 512,
        color = CONTROL_BUTTONS_UP_COLOR,
      },
      refresh = {
        id = IOTA(),
        text = "\x13",
        x = W,
        y = 1,
        color = "3",
      },
      resetAmount = {
        id = IOTA(),
        text = "x",
        x = 9,
        y = H,
        color = "e",
      },
    },
  },
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

local function centerString(line, width)
  local pad = width - #line
  local left = math.floor(pad / 2)
  local right = pad - left

  return string.rep(" ", left) .. line .. string.rep(" ", right)
end

local function initUI()
  term.clear()

  local line1 = "Storage"
  local line2 = "Master"

  local line1x = math.floor((W / 2) - (#line1 / 2))
  term.setCursorPos(line1x, 1)
  term.write(line1)

  local line2x = math.floor((W / 2) - (#line2 / 2))
  term.setCursorPos(line2x, 2)
  term.write(line2)

  local tabStorageWidth = UI.tabs.storage.xEnd - UI.tabs.storage.xStart
  local tabPlayerWidth = UI.tabs.player.xEnd - UI.tabs.player.xStart

  UI.tabs.storage.name = centerString(UI.tabs.storage.name, tabStorageWidth)
  UI.tabs.player.name = centerString(UI.tabs.player.name, tabPlayerWidth)
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
  UI.tabs.player.focusedItem = 0
  UI.tabs.player.scroll = 0
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
  UI.tabs.storage.focusedItem = 0
  UI.tabs.storage.scroll = 0
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

  term.setBackgroundColor(colors.black)

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
  for yi = UI.sendRequestControls.yStart, UI.sendRequestControls.yEnd do
    term.setCursorPos(1, yi)
    term.clearLine()
  end

  local amountMaxLen = UI.sendRequestControls.amount.xEnd - UI.sendRequestControls.amount.xStart + 1
  local amountStr = tostring(UI.sendRequestControls.amount.n)
  local amountLen = #amountStr

  local amountRenderStr = string.rep("0", amountMaxLen - amountLen) .. amountStr

  term.setCursorPos(UI.sendRequestControls.amount.xStart, UI.sendRequestControls.amount.y)
  term.blit(
    amountRenderStr,
    string.rep("0", #amountRenderStr),
    string.rep("f", #amountRenderStr))

  ---@type {id: number, text: string, x: number, y: number, color: string}
  local tabButton = {}

  if UI.tabs.tabActiveId == UI.tabs.player.id then
    tabButton = UI.sendRequestControls.buttons.player
  elseif UI.tabs.tabActiveId == UI.tabs.storage.id then
    tabButton = UI.sendRequestControls.buttons.storage
  end

  ---@param btn {id: number, text: string, x: number, y: number, color: string}
  local function renderButton(btn)
    local fg = BUTTON_UNPRESSED_FG
    local bg = BUTTON_UNPRESSED_BG
    if btn.id == UI.sendRequestControls.pressedButtonId then
      fg = BUTTON_PRESSED_FG
      bg = btn.color
    end

    term.setCursorPos(btn.x, btn.y)
    term.blit(
      btn.text,
      string.rep(fg, #btn.text),
      string.rep(bg, #btn.text))
  end

  renderButton(tabButton)

  for k, v in pairs(UI.sendRequestControls.buttons) do
    if k == "storage" or k == "player" then
      goto continue
    end

    renderButton(v)

    ::continue::
  end

  UI.sendRequestControls.pressedButtonId = 0
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
        count = UI.sendRequestControls.amount.n,
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
  local count = UI.sendRequestControls.amount.n

  rednet.send(GLB.server,
    {
      code = "SEND_FROM_INV",
      data = {
        count = count,
        name = item.name,
        nbt = item.nbt,
      }
    },
    "storage")

  item.count = math.min(0, item.count - count)
end

MOUSE_BUTTON_LEFT = 1
MOUSE_BUTTON_RIGHT = 2
local function processMouseClick(x, y, mouseButton)
  UI.focusedId = 0

  -- check if tabs were clicked
  if y == UI.tabs.y then
    UI.sendRequestControls.amount.n = 64
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
    if mouseButton == MOUSE_BUTTON_RIGHT then
      UI.searchBar.query = ""
    end

    return
  end

  local resetBtn = UI.sendRequestControls.buttons.resetAmount
  if y == resetBtn.y and x == resetBtn.x then
    UI.sendRequestControls.pressedButtonId = resetBtn.id
    UI.sendRequestControls.amount.n = 64

    return
  end

  if y >= UI.sendRequestControls.yStart and y <= UI.sendRequestControls.yEnd then
    local invButton = {}
    if UI.tabs.tabActiveId == UI.tabs.player.id then
      invButton = UI.sendRequestControls.buttons.player
    elseif UI.tabs.tabActiveId == UI.tabs.storage.id then
      invButton = UI.sendRequestControls.buttons.storage
    end

    if y == invButton.y and x >= invButton.x and x <= (invButton.x + #invButton.text - 1) then
      UI.sendRequestControls.pressedButtonId = invButton.id

      if invButton.id == UI.sendRequestControls.buttons.player.id then
        sendItemFromInv()
      else
        requestItemFromStorage()
      end

      return
    end

    for name, btn in pairs(UI.sendRequestControls.buttons) do
      if btn.n == nil then
        goto continue
      end

      if y == btn.y and x >= btn.x and x <= (btn.x + #btn.text - 1) then
        UI.sendRequestControls.pressedButtonId = btn.id

        local ndiff = btn.n
        UI.sendRequestControls.buttons[name].color = CONTROL_BUTTONS_UP_COLOR

        if mouseButton == MOUSE_BUTTON_RIGHT then
          ndiff = -ndiff
          UI.sendRequestControls.buttons[name].color = CONTROL_BUTTONS_DOWN_COLOR
        end

        local maxItemAmount = 27 * 64
        UI.sendRequestControls.amount.n = clamp(UI.sendRequestControls.amount.n + ndiff, 1, maxItemAmount)
        break
      end

      ::continue::
    end

    return
  end

  local refBtn = UI.sendRequestControls.buttons.refresh
  if y == refBtn.y and x == refBtn.x then
    UI.sendRequestControls.pressedButtonId = refBtn.id

    if UI.tabs.tabActiveId == UI.tabs.player.id then
      fetchPlayerInventory()
    elseif UI.tabs.tabActiveId == UI.tabs.storage.id then
      fetchStorage()
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

fetchPlayerInventory()
fetchStorage()
UI.tabs.storage.window.setVisible(true)

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

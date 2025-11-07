MODEM_PERIPHERAL = "back"
PROTOCOL = "storage"

GLB = {
  modem = nil,
  server = nil,
}

WINDOW_BOUNDS = {
  yStart = 5,
  yEnd = -1
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
  WINDOW_BOUNDS.yEnd = H - 1

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
    WINDOW_BOUNDS.yEnd - WINDOW_BOUNDS.yStart, false)
  UI.tabs.player.window = window.create(term.current(), 1, WINDOW_BOUNDS.yStart, W,
    WINDOW_BOUNDS.yEnd - WINDOW_BOUNDS.yStart, false)
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
      assert(data)
      assert(data.code == "PLAYER_INVENTORY")
      UI.tabs.player.inventory = data.data
    end
  )
  UI.tabs.player.focusedItem = 0
end

local function renderPlayerTab()
  term.redirect(UI.tabs.player.window)

  UI.tabs.player.filteredInventory = {}
  if UI.searchBar.query == "" then
    UI.tabs.player.filteredInventory = UI.tabs.player.inventory
  else
    local q = string.lower(UI.searchBar.query)
    for i = 1, #UI.tabs.player.inventory do
      if string.find(string.lower(UI.tabs.player.inventory[i].displayName), q) ~= nil then
        UI.tabs.player.filteredInventory[#UI.tabs.player.filteredInventory + 1] = UI.tabs.player.inventory[i]
      end
    end
  end

  term.clear()
  for i = 1 + UI.tabs.player.scroll, #UI.tabs.player.filteredInventory do
    if i == UI.tabs.player.focusedItem then
      term.setTextColor(colors.black)
      term.setBackgroundColor(colors.white)
    else
      term.setTextColor(colors.lightGray)
      term.setBackgroundColor(colors.black)
    end
    term.setCursorPos(1, i - UI.tabs.player.scroll)
    term.write(UI.tabs.player.filteredInventory[i].count .. " " .. UI.tabs.player.filteredInventory[i].displayName)
  end

  term.redirect(UI.term)
end

local function renderTabs()
  renderTabNames()

  if UI.tabs.player.id == UI.focusedId then
    renderPlayerTab()
  end
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

  if UI.focusedId == UI.searchBar.id then
    term.setCursorPos(#line + 1, UI.searchBar.y)
    term.setCursorBlink(true)
  end
end

local function renderUI()
  term.setCursorBlink(false)

  renderTabs()
  renderSearchBar()
end

local function processMouseClick(x, y, button)
  _ = button

  UI.focusedId = 0

  -- check if tabs were clicked
  if y == UI.tabs.y then
    if x >= UI.tabs.storage.xStart and x < UI.tabs.storage.xEnd then
      UI.tabs.tabActiveId = UI.tabs.storage.id
      UI.focusedId = UI.tabs.storage.id

      UI.tabs.storage.window.setVisible(true)
      UI.tabs.player.window.setVisible(false)
    elseif x >= UI.tabs.player.xStart and x < UI.tabs.player.xEnd then
      UI.tabs.tabActiveId = UI.tabs.player.id
      UI.focusedId = UI.tabs.player.id
      fetchPlayerInventory()

      UI.tabs.storage.window.setVisible(false)
      UI.tabs.player.window.setVisible(true)
    end

    return
  end

  if y >= WINDOW_BOUNDS.yStart and y <= WINDOW_BOUNDS.yEnd then
    if UI.tabs.tabActiveId == UI.tabs.player.id then
      UI.tabs.player.focusedItem = y - WINDOW_BOUNDS.yStart + 1 + UI.tabs.player.scroll
      renderPlayerTab()
    elseif UI.tabs.tabActiveId == UI.tabs.storage.id then
    end

    return
  end

  if y == UI.searchBar.y then
    UI.focusedId = UI.searchBar.id
    return
  end
end

local function processChar(c)
  if UI.focusedId == UI.searchBar.id then
    UI.searchBar.query = UI.searchBar.query .. c

    if UI.tabs.tabActiveId == UI.tabs.player.id then
      UI.tabs.player.focusedItem = 0
      UI.tabs.player.scroll = 0
      renderPlayerTab()
    end
  end
end

local function processKeyPress(key)
  if UI.focusedId == UI.searchBar.id and key == keys.backspace then
    UI.searchBar.query = string.sub(UI.searchBar.query, 1, -2)

    if UI.tabs.tabActiveId == UI.tabs.player.id then
      UI.tabs.player.focusedItem = 0
      UI.tabs.player.scroll = 0
      renderPlayerTab()
    end
  end
end

---@param a number
---@param min number
---@param max number
---@return number
local function clamp(a, min, max)
  return math.min(max, math.max(min, a))
end

local function processMouseScroll(dir, _, y)
  if y >= WINDOW_BOUNDS.yStart and y <= WINDOW_BOUNDS.yEnd then
    if UI.tabs.tabActiveId == UI.tabs.player.id then
      UI.tabs.player.scroll = clamp(UI.tabs.player.scroll + dir, 0, 27)
      renderPlayerTab()
    elseif UI.tabs.tabActiveId == UI.tabs.storage.id then
    end

    return
  end
end

init()

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

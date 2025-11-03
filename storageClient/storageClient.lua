MODEM_PERIPHERAL = "back"
PROTOCOL = "storage"

GLB = {
  modem = nil,
  server = nil,
}

-- ui state
UI = {
  focusedId = 1,
  tabs = {
    tabActiveId = 1,
    y = 4,
    storage = {
      id = 1,
      name = "",
      xStart = 0,
      xEnd = 0,
    },
    player = {
      id = 2,
      name = "",
      xStart = 0,
      xEnd = 0,
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

  GLB.server = rednet.lookup(PROTOCOL, "main")
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

local function renderTabs()
  renderTabNames()
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
    term.setCursorPos(#line+1, UI.searchBar.y)
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
    elseif x >= UI.tabs.player.xStart and x < UI.tabs.player.xEnd then
      UI.tabs.tabActiveId = UI.tabs.player.id
      UI.focusedId = UI.tabs.player.id
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
  end
end

local function processKeyPress(key)
  if UI.focusedId == UI.searchBar.id and key == keys.backspace then
    UI.searchBar.query = string.sub(UI.searchBar.query, 1, -2)
  end
end

init()

while true do
  renderUI()

  local eventData = { os.pullEvent() }
  local event = eventData[1]

  if event == "mouse_click" then
    processMouseClick(eventData[3], eventData[4], eventData[2])
  elseif event == "char" then
    processChar(eventData[2])
  elseif event == "key" then
    processKeyPress(eventData[2])
  end
end

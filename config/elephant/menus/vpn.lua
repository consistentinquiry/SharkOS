Name = "vpn"
NamePretty = "VPN"
HideFromProviderlist = true
Cache = false
FixedOrder = true

local home = os.getenv("HOME") or ""
local icons_dir = home .. "/.config/hypr/icons"
local script = home .. "/.config/hypr/scripts/vpn-action.sh"

local function exec(c)
  local h = io.popen(c)
  if not h then return "" end
  local out = h:read("*a") or ""
  h:close()
  return out
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function has_cmd(name)
  return trim(exec("which " .. name .. " 2>/dev/null")) ~= ""
end

function GetEntries(query)
  local entries = {}

  -- WireGuard
  if has_cmd("wg") then
    local active = exec("wg show interfaces 2>/dev/null")
    local seen = {}

    local h = io.popen("ls /etc/wireguard/*.conf 2>/dev/null")
    if h then
      for conf in h:lines() do
        local iface = conf:match(".*/(.+)%.conf$")
        if iface and not seen[iface] then
          seen[iface] = true
          local connected = active:find(iface, 1, true) ~= nil
          local action = connected and "disconnect" or "connect"
          local label = "WireGuard (" .. iface .. ")"
          if connected then label = label .. "  ← connected" end
          table.insert(entries, {
            Text = label,
            Icon = icons_dir .. "/wireguard.svg",
            Actions = { activate = script .. " wireguard " .. iface .. " " .. action },
          })
        end
      end
      h:close()
    end
  end

  -- Netbird
  if has_cmd("netbird") then
    local status = exec("netbird status 2>/dev/null")
    local connected = status:find("Management: Connected") ~= nil
    local action = connected and "disconnect" or "connect"
    local label = "Netbird"
    if connected then label = label .. "  ← connected" end
    table.insert(entries, {
      Text = label,
      Icon = icons_dir .. "/netbird.svg",
      Actions = { activate = script .. " netbird default " .. action },
    })
  end

  -- NordVPN
  if has_cmd("nordvpn") then
    local status = exec("nordvpn status 2>/dev/null")
    local connected = status:find("Connected") ~= nil and status:find("Disconnected") == nil
    local action = connected and "disconnect" or "connect"
    local label = "NordVPN"
    if connected then
      local city = status:match("City:%s*(.+)")
      if city then
        label = label .. "  ← " .. trim(city)
      else
        label = label .. "  ← connected"
      end
    end
    table.insert(entries, {
      Text = label,
      Icon = "/usr/share/icons/hicolor/scalable/apps/nordvpn.svg",
      Actions = { activate = script .. " nordvpn default " .. action },
    })
  end

  return entries
end

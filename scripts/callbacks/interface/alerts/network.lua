--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "alert_utils"

alerts_api = require("alerts_api")

local do_trace      = false
local config_alerts = nil
local ifname        = nil
local available_modules = nil

-- The function below ia called once (#pragma once)
function setup(str_granularity)
   if do_trace then print("alert.lua:setup("..str_granularity..") called\n") end
   ifname = interface.setActiveInterfaceId(tonumber(interface.getId()))
   config_alerts = getNetworksConfiguredAlertThresholds(ifname, str_granularity)

   -- Load the threshold checking functions
   available_modules = alerts_api.load_check_modules("network")
end

-- #################################################################

-- The function below is called once per local network
function checkNetworkAlerts(granularity)
   local info = network.getNetworkStats()
   local network_key = info and info.network_key

   if not network_key then
      return
   end

   local network_config = config_alerts[network_key]
   local global_config = config_alerts["local_networks"]
   local has_configured_alerts = (table.len(network_config or global_config or {}) > 0)

   if(has_configured_alerts) then
      for _, check in pairs(available_modules) do
        local config = network_config[check.key] or global_config[check.key]

        if config then
           check.check_function({
              granularity = granularity,
              alert_entity = alerts_api.networkAlertEntity(network_key),
              entity_info = info,
              alert_config = config,
              check_module = check,
           })
        end
      end
   end
end
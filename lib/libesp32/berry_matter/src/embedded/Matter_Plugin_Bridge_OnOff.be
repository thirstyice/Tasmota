#
# Matter_Plugin_Bridge_OnOff.be - implements the behavior for a Relay via HTTP (OnOff)
#
# Copyright (C) 2023  Stephan Hadinger & Theo Arends
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Matter plug-in for core behavior

# dummy declaration for solidification
class Matter_Plugin_Bridge_HTTP end

#@ solidify:Matter_Plugin_Bridge_OnOff,weak

class Matter_Plugin_Bridge_OnOff : Matter_Plugin_Bridge_HTTP
  static var TYPE = "http_relay"                    # name of the plug-in in json
  static var NAME = "&#x1F517; Relay"                       # display name of the plug-in
  static var ARG  = "relay"                         # additional argument name (or empty if none)
  static var ARG_TYPE = / x -> int(x)               # function to convert argument to the right type
  static var CLUSTERS  = {
    # 0x001D: inherited                             # Descriptor Cluster 9.5 p.453
    # 0x0003: inherited                             # Identify 1.2 p.16
    # 0x0004: inherited                             # Groups 1.3 p.21
    # 0x0005: inherited                             # Scenes 1.4 p.30 - no writable
    0x0006: [0,0xFFFC,0xFFFD],                      # On/Off 1.5 p.48
  }
  static var TYPES = { 0x010A: 2 }       # On/Off Light

  var tasmota_relay_index                           # Relay number in Tasmota (zero based)
  var shadow_onoff                                  # fake status for now # TODO

  #############################################################
  # Constructor
  def init(device, endpoint, arguments)
    import string
    super(self).init(device, endpoint, arguments)
    self.shadow_onoff = false
    self.tasmota_relay_index = arguments.find(self.ARG #-'relay'-#)
    if self.tasmota_relay_index == nil     self.tasmota_relay_index = 0   end
  end

  #############################################################
  # Update shadow
  #
  def update_shadow()
    var ret = self.call_remote_sync("Status", "11")
    super(self).update_shadow()
  end

  #############################################################
  # Stub for updating shadow values (local copies of what we published to the Matter gateway)
  #
  # TO BE OVERRIDDEN
  # This call is synnchronous and blocking.
  def parse_update(data, index)
    if index == 11                              # Status 11
      var state = (data.find("POWER") == "ON")
      if self.shadow_onoff != nil && self.shadow_onoff != bool(state)
        self.attribute_updated(0x0006, 0x0000)
      end
      self.shadow_onoff = state
    end
  end

  #############################################################
  # probe_shadow_async
  #
  # ### TO BE OVERRIDDEN - DON'T CALL SUPER - default is just calling `update_shadow()`
  # This is called on a regular basis, depending on the type of plugin.
  # Whenever the data is returned, call `update_shadow(<data>)` to update values
  def probe_shadow_async()
    self.call_remote_async("Status", "11")
  end

  #############################################################
  # Model
  #
  def set_onoff(v)
    self.call_remote_sync("Power", v ? "1" : "0")
    self.update_shadow()
  end

  #############################################################
  # read an attribute
  #
  def read_attribute(session, ctx)
    import string
    var TLV = matter.TLV
    var cluster = ctx.cluster
    var attribute = ctx.attribute

    # ====================================================================================================
    if   cluster == 0x0006              # ========== On/Off 1.5 p.48 ==========
      self.update_shadow_lazy()
      if   attribute == 0x0000          #  ---------- OnOff / bool ----------
        return TLV.create_TLV(TLV.BOOL, self.shadow_onoff)
      elif attribute == 0xFFFC          #  ---------- FeatureMap / map32 ----------
        return TLV.create_TLV(TLV.U4, 0)    # 0 = no Level Control for Lighting
      elif attribute == 0xFFFD          #  ---------- ClusterRevision / u2 ----------
        return TLV.create_TLV(TLV.U4, 4)    # 0 = no Level Control for Lighting
      end

    else
      return super(self).read_attribute(session, ctx)
    end
  end

  #############################################################
  # Invoke a command
  #
  # returns a TLV object if successful, contains the response
  #   or an `int` to indicate a status
  def invoke_request(session, val, ctx)
    var TLV = matter.TLV
    var cluster = ctx.cluster
    var command = ctx.command

    # ====================================================================================================
    if   cluster == 0x0006              # ========== On/Off 1.5 p.48 ==========
      self.update_shadow_lazy()
      if   command == 0x0000            # ---------- Off ----------
        self.set_onoff(false)
        self.update_shadow()
        return true
      elif command == 0x0001            # ---------- On ----------
        self.set_onoff(true)
        self.update_shadow()
        return true
      elif command == 0x0002            # ---------- Toggle ----------
        self.set_onoff(!self.shadow_onoff)
        self.update_shadow()
        return true
      end
    end

  end

end
matter.Plugin_Bridge_OnOff = Matter_Plugin_Bridge_OnOff

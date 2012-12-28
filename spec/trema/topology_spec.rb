#
# Copyright (C) 2008-2013 NEC Corporation
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#

require File.join( File.dirname( __FILE__ ), "..", "spec_helper" )
require "trema"
require "trema/topology"
require "trema/topology/topology_cache"


include Trema::Topology

describe Trema::Topology, :nosudo => true do

  describe "Constants from enum topology_switch_status_type" do
    it "has TD_SWITCH_DOWN" do
      expect(Topology::TD_SWITCH_DOWN).to eq(0)
    end
    it "has TD_SWITCH_UP" do
      expect(Topology::TD_SWITCH_UP).to eq(1)
    end
  end

  describe "Constants from enum topology_port_status_type" do
    it "has TD_PORT_DOWN" do
      expect(Topology::TD_PORT_DOWN).to eq(0)
    end
    it "has TD_PORT_UP" do
      expect(Topology::TD_PORT_UP).to eq(1)
    end
  end

  describe "Constants from enum topology_port_external_type" do
    it "has TD_PORT_INACTIVE" do
      expect(Topology::TD_PORT_INACTIVE).to eq(0)
    end
    it "has TD_PORT_EXTERNAL" do
      expect(Topology::TD_PORT_EXTERNAL).to eq(1)
    end
  end

  describe "Constants from enum topology_link_status_type" do
    it "has TD_LINK_DOWN" do
      expect(Topology::TD_LINK_DOWN).to eq(0)
    end
    it "has TD_LINK_UP" do
      expect(Topology::TD_LINK_UP).to eq(1)
    end
    it "has TD_LINK_UNSTABLE" do
      expect(Topology::TD_LINK_UNSTABLE).to eq(2)
    end
  end
end

### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:

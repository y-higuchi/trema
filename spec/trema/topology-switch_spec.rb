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

  describe Switch do
    it "should be initialized like Hash" do
      expect {
        s = Switch[ {:dpid => 0x1234 } ]
      }.not_to raise_error
    end

    it "should raise error if empty instance is being created" do
      expect {
        s = Switch.new
      }.to raise_error()
    end

    it "should raise error if key :dpid missing" do
      expect {
        s = Switch[ { :portno => 42 } ]
      }.to raise_error(ArgumentError)
    end

    it "should have dpid accessor" do
      s = Switch[ { :dpid => 0x1234, :magic => 42 } ]
      expect( s.dpid ).to be == 0x1234
    end

    it "has method up?" do
      s = Switch[ { :dpid => 0x1234, :magic => 42, :up => true } ]
      expect( s.up? ).to be_true

      s = Switch[ { :dpid => 0x1234, :magic => 42, :up => false } ]
      expect( s.up? ).to be_false

      s = Switch[ { :dpid => 0x1234, :magic => 42 } ]
      expect( s.up? ).to be_false
    end

    it "should have method key" do
      s = Switch[ { :dpid => 0x1234, :magic => 42 } ]
      expect( s.key ).to be == 0x1234
    end

    it "should have method key_str" do
      s = Switch[ { :dpid => 0x1234, :magic => 42 } ]
      expect( s.key_str ).to match("1234")
    end


    it "should have port manipulation methods" do
      s = Switch[ { :dpid => 0x1234, :magic => 42 } ]

      s.add_port Port[ { :dpid => 0x1234, :portno => 1 } ]
      expect( s.ports[1] ).not_to be_nil

      s.add_port_by_portno 2
      expect( s.ports[2] ).not_to be_nil

      s.update_port_by_hash( { :dpid => 0x1234, :portno => 3, :up => true } )
      expect( s.ports[3] ).not_to be_nil

      s.del_port Port[ { :dpid => 0x1234, :portno => 2 } ]
      expect( s.ports[2] ).to be_nil

      s.del_port_by_portno 3
      expect( s.ports[3] ).to be_nil

      s.update_port_by_hash( { :dpid => 0x1234, :portno => 1, :up => false } )
      expect( s.ports[1] ).to be_nil
    end

    it "should have link manipulation methods" do
      s1 = Switch[ { :dpid => 0x1234, :magic => 42 } ]
      s2 = Switch[ { :dpid => 0x5678, :magic => 42 } ]

      l1 = Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ]
      l2 = Link[ {:from_dpid => 0x5678, :from_portno => 72, :to_dpid => 0x1234, :to_portno => 42 } ]

      s1.add_outbound_link l1
      expect( s1.links_out.empty? ).not_to be_true
      s2.add_inbound_link l1
      expect( s2.links_in.empty? ).not_to be_true

      s1.add_inbound_link l2
      expect( s1.links_in.empty? ).not_to be_true
      s2.add_outbound_link l2
      expect( s2.links_out.empty? ).not_to be_true

      s1.del_inbound_link l2
      s1.del_outbound_link l1
      expect( s1.links_in.empty? ).to be_true
      expect( s1.links_out.empty? ).to be_true

      s2.del_link_by_key l1.key
      s2.del_link_by_key l2.key
      expect( s2.links_in.empty? ).to be_true
      expect( s2.links_out.empty? ).to be_true
    end

    it "should be serializable to human readable form by to_s" do
      s = Switch[ { :dpid => 0x1234, :up => true, :magic => 42 } ]
      s.add_port Port[ { :dpid => 0x1234, :portno => 42, :up => true, :not_used => 1 } ]
      s.add_outbound_link Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :not_used => 1 } ]
      s.add_inbound_link Link[ {:from_dpid => 0xABCD, :from_portno => 102, :to_dpid => 0x1234, :to_portno => 42, :not_used => 1 } ]
      expect( s.to_s ).to be == <<-EOS
Switch: 0x1234 - {magic:42, up:true}
 Port: 0x1234:42 - {not_used:1, up:true}
 Links_in
  <= 0xabcd:102
 Links_out
  => 0x5678:72
      EOS
    end
  end
end

### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:

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

  describe Cache do
    it "should initialize it's members to empty" do
      c = Cache.new
      expect( c.switches.empty? ).to be_true
      expect( c.links.empty? ).to be_true
    end

    it "should have switch manipulation methods" do
      c = Cache.new
      c.add_switch Switch[ {:dpid => 0x1234 } ]
      expect( c.switches.empty? ).to be_false

      expect( c.lookup_switch_by_dpid( 0x1234 ) ).not_to be_nil

      c.add_switch Switch[ {:dpid => 0x5678 } ]
      expect( c.switches[ 0x5678 ] ).not_to be_nil

      c.del_switch Switch[ {:dpid => 0x5678 } ]
      c.del_switch_by_dpid 0x1234
      expect( c.switches.empty? ).to be_true
    end

    it "should have link manipulation methods" do
      c = Cache.new
      c.add_switch Switch[ {:dpid => 0x1234 } ]
      c.add_switch Switch[ {:dpid => 0x5678 } ]

      c.add_link Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ]
      expect( c.links.empty? ).to be_false

      expect( c.lookup_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ) ).not_to be_nil

      c.del_link Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ]
      expect( c.lookup_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ) ).to be_nil

      c.add_link Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ]
      c.del_link_by_key_elements 0x1234, 42, 0x5678, 72
      expect( c.lookup_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ) ).to be_nil

      c.add_link Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ]
      c.del_link_by_key_tuple [0x1234, 42, 0x5678, 72]
      expect( c.lookup_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ) ).to be_nil

      expect( c.links.empty? ).to be_true
    end

    describe "Switch events" do
      it "should add Switch on switch up event" do
        c = Cache.new
        c.update_switch_by_hash( {:dpid => 0x1234, :status => 1, :up => true } )
        expect( c.switches ).to include(0x1234)

        expect( c.switches[ 0x1234 ][:status] ).to be == 1
        expect( c.switches[ 0x1234 ][:up] ).to be_true
      end

      it "should delete Switch on switch up event" do
        c = Cache.new
        c.add_switch Switch[ {:dpid => 0x1234, :status => 1, :up => true } ]
        c.add_switch Switch[ {:dpid => 0x5678, :status => 1, :up => true } ]

        c.update_switch_by_hash( {:dpid => 0x1234, :status => 0, :up => false } )
        expect( c.switches ).not_to include(0x1234)
        expect( c.switches ).to include(0x5678)
      end

      it "should update Switch on existing switch's up event" do
        c = Cache.new
        c.add_switch Switch[ {:dpid => 0x1234, :status => 1, :up => true, :extra => "Old Value", :no_change => true } ]
        c.update_switch_by_hash( {:dpid => 0x1234, :status => 1, :up => true, :extra => "New Value" } )
        expect( c.switches ).to include(0x1234)
        expect( c.switches[ 0x1234 ][:status] ).to be == 1
        expect( c.switches[ 0x1234 ][:up] ).to be_true
        expect( c.switches[ 0x1234 ][:extra] ).to match("New Value")
        expect( c.switches[ 0x1234 ][:no_change] ).to be_true
      end
    end

    describe "Link event" do
      before do
        @c = Cache.new
        @c.add_switch Switch[ {:dpid => 0x1234, :status => 1, :up => true } ]
        @c.add_switch Switch[ {:dpid => 0x5678, :status => 1, :up => true } ]
      end

      it "should add Link on link up event" do
        @c.update_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :status => 0, :up => true, :unstable => false } )
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ] ).not_to be_nil
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ][:status] ).to be == 0
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ][:up] ).to be_true
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ][:unstable] ).to be_false

        expect( @c.switches[0x1234].links_out[ [0x1234, 42, 0x5678, 72] ] ).not_to be_nil
        expect( @c.switches[0x5678].links_in[ [0x1234, 42, 0x5678, 72] ] ).not_to be_nil
      end

      it "should remove Link on link down event" do
        @c.add_link Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ]
        expect( @c.links.empty? ).to be_false

        @c.update_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :status => 1, :up => false, :unstable => false } )
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ] ).to be_nil
      end

      it "should update Link on existing link event" do
        @c.update_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :status => 1, :up => true, :unstable => false } )

        @c.update_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :up => true, :unstable => true } )
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ] ).not_to be_nil
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ][:status] ).to be == 1
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ][:up] ).to be_true
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ][:unstable] ).to be_true

        expect( @c.switches[0x1234].links_out[ [0x1234, 42, 0x5678, 72] ] ).not_to be_nil
        expect( @c.switches[0x5678].links_in[ [0x1234, 42, 0x5678, 72] ] ).not_to be_nil
      end
    end

    describe "Link event recoverable error" do
      before do
        @c = Cache.new
      end
      it "should add Switch and Link on link up event, when switch did not exist" do
        @c.update_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :status => 0, :up => true, :unstable => false } )
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ] ).not_to be_nil
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ][:status] ).to be == 0
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ][:up] ).to be_true
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ][:unstable] ).to be_false

        expect( @c.switches[0x1234].links_out[ [0x1234, 42, 0x5678, 72] ] ).not_to be_nil
        expect( @c.switches[0x5678].links_in[ [0x1234, 42, 0x5678, 72] ] ).not_to be_nil
      end
    end

    describe "Port event" do
      before do
        @c = Cache.new
        @c.add_switch Switch[ {:dpid => 0x1234, :status => 1, :up => true } ]
        @c.add_switch Switch[ {:dpid => 0x5678, :status => 1, :up => true } ]
      end

      it "should add Port on port up event" do
        @c.update_port_by_hash( { :dpid => 0x1234, :portno => 42, :name => "Port Name", :mac => "FF:FF:FF:FF:FF:FF", :external => 0, :status => 0, :up => true } )
        expect( @c.switches[0x1234].ports[42][:name] ).to match("Port Name")
      end

      it "should delete Port on port down event" do
        @c.update_port_by_hash( { :dpid => 0x1234, :portno => 42, :name => "Port Name", :mac => "FF:FF:FF:FF:FF:FF", :external => 0, :status => 1, :up => false } )
        expect( @c.switches[0x1234].ports ).not_to include(42)
      end

      it "should update Port on existing port up event" do
        @c.update_port_by_hash( { :dpid => 0x1234, :portno => 42, :name => "Port Name", :mac => "FF:FF:FF:FF:FF:FF", :external => 0, :status => 0, :up => true } )
        @c.update_port_by_hash( { :dpid => 0x1234, :portno => 42, :name => "New Port Name", :external => 0, :status => 0, :up => true } )
        expect( @c.switches[0x1234].ports[42][:name] ).to match("Port Name")
        expect( @c.switches[0x1234].ports[42][:mac] ).to match("FF:FF:FF:FF:FF:FF")
      end
    end

    describe "Port event recoverable error" do
      before do
        @c = Cache.new
      end
      it "should add Switch and Port on port up event, when switch did not exist" do
        @c.update_port_by_hash( { :dpid => 0x1234, :portno => 42, :name => "Port Name", :mac => "FF:FF:FF:FF:FF:FF", :external => 0, :status => 0, :up => true } )
        expect( @c.switches[0x1234].ports[42][:name] ).to match("Port Name")
      end
    end

    it "should be serializable to human readable form by to_s" do
      c = Cache.new

      s = Switch[ { :dpid => 0x1234, :up => true, :magic => 42 } ]
      s.add_port Port[ { :dpid => 0x1234, :portno => 42, :up => true, :not_used => 1 } ]
      c.add_switch s
      c.add_link Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :not_used => 1, :up => true } ]
      c.add_link Link[ {:from_dpid => 0xABCD, :from_portno => 102, :to_dpid => 0x1234, :to_portno => 42, :not_used => 1, :up => true } ]
      expect( c.to_s ).to be == <<-EOS
Cache:
Switch: 0x1234 - {magic:42, up:true}
 Port: 0x1234:42 - {not_used:1, up:true}
 Links_in
  <= 0xabcd:102
 Links_out
  => 0x5678:72
Switch: 0xabcd - {}
 Links_out
  => 0x1234:42
Switch: 0x5678 - {}
 Links_in
  <= 0x1234:42
Link: (0xabcd:102)->(0x1234:42) - {not_used:1, up:true}
Link: (0x1234:42)->(0x5678:72) - {not_used:1, up:true}
      EOS
    end
  end

  describe "Cache management functions" do
    before do
      class DummyController
        include Topology
      end
      @c = DummyController.new
    end

    it "should respond to get_cache, cache_ready?, cache_up_to_date?" do
      expect( @c ).to respond_to( :get_cache, :cache_ready?, :cache_up_to_date? )
    end

    it "should issue all status request on rebuild request" do

      expect( @c.cache_up_to_date? ).to be_false

      @c.should_receive(:send_all_switch_status_request).and_yield( [ {:dpid => 0x1234, :up => true } ] )
      @c.should_receive(:send_all_port_status_request).and_yield( [ {:dpid => 0x1234, :portno => 42, :up => true } ] )
      @c.should_receive(:send_all_link_status_request).and_yield( [ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :up => true } ] )

      @c.should_receive(:cache_ready).once

      @c.send_rebuild_cache_request

      expect( @c.cache_up_to_date? ).to be_true
    end

    it "should update Cache on Switch update event" do
      @c.update_cache_by_switch_hash( {:dpid => 0x1234, :up => true } )
      cache = @c.get_cache
      expect( cache.lookup_switch_by_dpid( 0x1234 ) ).not_to be_nil

      @c.update_cache_by_switch_hash( {:dpid => 0x1234, :up => false } )
      cache = @c.get_cache
      expect( cache.lookup_switch_by_dpid( 0x1234 ) ).to be_nil
    end

    it "should update Cache on Port update event" do
      @c.update_cache_by_port_hash( {:dpid => 0x1234, :portno => 42, :up => true } )
      cache = @c.get_cache
      expect( cache.lookup_switch_by_dpid( 0x1234 ).ports[42] ).not_to be_nil

      @c.update_cache_by_port_hash( {:dpid => 0x1234, :portno => 42, :up => false } )
      cache = @c.get_cache
      expect( cache.lookup_switch_by_dpid( 0x1234 ).ports[42] ).to be_nil
    end

    it "should update Cache on Link update event" do
      @c.update_cache_by_link_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :up => true } )
      cache = @c.get_cache
      expect( cache.lookup_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ) ).not_to be_nil

      @c.update_cache_by_link_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :up => false } )
      cache = @c.get_cache
      expect( cache.lookup_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ) ).to be_nil
    end


  end
end

### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:

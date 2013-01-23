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
require "trema/topology/map_api"


include Trema::TopologyMap

describe Trema::TopologyMap, :nosudo => true do

  describe "Monkey patched Switch" do
    it "should have method key_str" do
      s = Switch.new( { :dpid => 0x1234, :magic => 42 } )
      expect( s.key_str ).to match("1234")
    end

    it "up state should be overwritable" do
      s = Switch.new( { :dpid => 0x1234, :up => true } )
      s.up = false
      expect( s.up? ).to be_false

      s = Switch.new( { :dpid => 0x1234, :up => false } )
      s.up = true
      expect( s.up? ).to be_true
    end

    describe "[],[]=" do
      before do
        @s = Switch.new( {:dpid => 0x1234, :extra => true } )
      end
      
      it "should have access to it's property" do
        expect( @s[:extra] ).to be_true
      end

      it "should be writable to non mandatory key" do
        @s[:extra] = false
        expect( @s[:extra] ).to be_false
      end

      it "should raise exception if attempt to write to non mandatory key" do
        expect {
          @s[:dpid] = 0x5678
        }.to raise_error(ArgumentError)
      end
    end

    describe "delete" do
      before do
        @s = Switch.new( {:dpid => 0x1234, :extra => true } )
      end
      
      it "should remove property value" do
        @s.delete(:extra)
        expect( @s.property.has_key?(:extra) ).to be_false
      end

      it "should ignore mandatory key" do
        @s.delete(:dpid)
        expect( @s[:dpid] ).to eq(0x1234)
      end
    end

    describe "update" do
      before do
        @s = Switch.new( {:dpid => 0x1234, :extra => true } )
      end
      it "should update property by given hash" do
        @s.update( {:extra => false, :new => 42})
        expect( @s[:extra] ).to be_false
        expect( @s[:new] ).to eq(42)
      end

      it "should ignore update to mandatory key" do
        @s.update( {:extra => false, :dpid => 42})
        expect( @s[:extra] ).to be_false
        expect( @s[:dpid] ).to eq(0x1234)
      end
    end
  end
  
  describe "Monkey Patched Port" do
    it "should have method key_str" do
      port = Port.new( {:dpid => 0x1234, :portno => 42 } )
      expect( port.key_str ).to match("1234-42")
    end
  end

  describe "Monkey Patched Link" do
    it "should have method key_str" do
      link = Link.new( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } )
      expect( link.key_str ).to match("1234-42-5678-72")
    end

    describe "[],[]=" do
      it "should have access to it's property" do
        link = Link.new( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :extra => true  } )
        expect( link[:extra] ).to be_true
      end

      it "should be writable to non mandatory key" do
        link = Link.new( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :extra => true  } )
        link[:extra] = false
        expect( link[:extra] ).to be_false
      end

      it "should raise exception if attempt to write to non mandatory key" do
        link = Link.new( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } )
        expect {
          link[:from_portno] = 55
        }.to raise_error(ArgumentError)
      end
    end

    describe "delete" do
      it "should remove property value" do
        link = Link.new( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :extra => true  } )
        link.delete(:extra)
        expect( link.property.has_key?(:extra) ).to be_false
      end

      it "should ignore mandatory key" do
        link = Link.new( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :extra => true  } )
        link.delete(:from_dpid)
        expect( link[:from_dpid] ).to eq(0x1234)
      end
    end

    describe "update" do
      it "should update property by given hash" do
        link = Link.new( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :extra => true  } )
        link.update( {:extra => false, :new => 42})
        expect( link[:extra] ).to be_false
        expect( link[:new] ).to eq(42)
      end

      it "should ignore update to mandatory key" do
        link = Link.new( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :extra => true  } )
        link.update( {:extra => false, :from_dpid => 42})
        expect( link[:extra] ).to be_false
        expect( link[:from_dpid] ).to eq(0x1234)
      end
    end
  end
  
  describe Map do
    it "should initialize it's members to empty" do
      c = Map.new
      expect( c.switches.empty? ).to be_true
      expect( c.links.empty? ).to be_true
    end

    it "should have switch manipulation methods" do
      c = Map.new
      c.add_switch Switch.new( {:dpid => 0x1234 } )
      expect( c.switches.empty? ).to be_false

      expect( c.lookup_switch_by_dpid( 0x1234 ) ).not_to be_nil

      c.add_switch Switch.new( {:dpid => 0x5678 } )
      expect( c.switches[ 0x5678 ] ).not_to be_nil

      c.del_switch Switch.new( {:dpid => 0x5678 } )
      c.del_switch_by_dpid 0x1234
      expect( c.switches.empty? ).to be_true
    end

    describe "link manipulation methods" do
      before do
        @c = Map.new
        @c.add_switch Switch.new( {:dpid => 0x1234 } )
        @c.add_switch Switch.new( {:dpid => 0x5678 } )
      end

      it "should have add_link" do
        @c.add_link Link.new( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } )
        expect( @c.links.empty? ).to be_false
      end

      it "should have lookup_link_by_hash" do
        @c.add_link Link.new( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } )
        expect( @c.lookup_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ) ).not_to be_nil
      end

      it "should have del_link(Link)" do
        @c.add_link Link.new( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } )
        @c.del_link Link.new( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } )
        expect( @c.lookup_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ) ).to be_nil
      end

      it "should have del_link(Hash)" do
        @c.add_link Link.new( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } )
        @c.del_link( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } )
        expect( @c.lookup_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ) ).to be_nil
      end

      it "should have del_link_by_key" do
        @c.add_link Link.new( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } )
        @c.del_link_by_key [0x1234, 42, 0x5678, 72]
        expect( @c.lookup_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ) ).to be_nil
      end
    end

    describe "Switch events" do
      it "should add Switch on switch up event" do
        c = Map.new
        c.update_switch( {:dpid => 0x1234, :up => true } )
        expect( c.switches ).to include(0x1234)

        expect( c.switches[ 0x1234 ].up? ).to be_true
        expect( c.switches[ 0x1234 ][:up] ).to be_true
      end

      it "should delete Switch on switch up event" do
        c = Map.new
        c.add_switch Switch.new( {:dpid => 0x1234, :up => true } )
        c.add_switch Switch.new( {:dpid => 0x5678, :up => true } )

        c.update_switch( {:dpid => 0x1234, :up => false } )
        expect( c.switches ).not_to include(0x1234)
        expect( c.switches ).to include(0x5678)
      end

      it "should update Switch on existing switch's up event" do
        c = Map.new
        c.add_switch Switch.new( {:dpid => 0x1234, :up => true, :extra => "Old Value", :no_change => true } )
        c.update_switch( {:dpid => 0x1234, :up => true, :extra => "New Value" } )
        expect( c.switches ).to include(0x1234)
        expect( c.switches[ 0x1234 ].up? ).to be_true
        expect( c.switches[ 0x1234 ][:up] ).to be_true
        expect( c.switches[ 0x1234 ][:extra] ).to match("New Value")
        expect( c.switches[ 0x1234 ][:no_change] ).to be_true
      end
    end

    describe "Link event" do
      before do
        @c = Map.new
        @c.add_switch Switch.new( {:dpid => 0x1234, :up => true } )
        @c.add_switch Switch.new( {:dpid => 0x5678, :up => true } )
      end

      it "should add Link on link up event" do
        @c.update_link( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :up => true, :unstable => false } )
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ] ).not_to be_nil
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ].up? ).to be_true
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ].unstable? ).to be_false
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ][:up] ).to be_true
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ][:unstable] ).to be_false

        expect( @c.switches[0x1234].links_out[ [0x1234, 42, 0x5678, 72] ] ).not_to be_nil
        expect( @c.switches[0x5678].links_in[ [0x1234, 42, 0x5678, 72] ] ).not_to be_nil
      end

      it "should remove Link on link down event" do
        @c.add_link Link.new( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } )
        expect( @c.links.empty? ).to be_false

        @c.update_link( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :up => false, :unstable => false } )
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ] ).to be_nil
      end

      it "should update Link on existing link event" do
        @c.update_link( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :up => true, :unstable => false } )

        @c.update_link( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :up => true, :unstable => true } )
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ] ).not_to be_nil
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ].up? ).to be_true
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ].unstable? ).to be_true
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ][:up] ).to be_true
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ][:unstable] ).to be_true

        expect( @c.switches[0x1234].links_out[ [0x1234, 42, 0x5678, 72] ] ).not_to be_nil
        expect( @c.switches[0x5678].links_in[ [0x1234, 42, 0x5678, 72] ] ).not_to be_nil
      end
    end

    describe "Link event recoverable error" do
      before do
        @c = Map.new
      end
      it "should add Switch and Link on link up event, when switch did not exist" do
        @c.update_link( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :up => true, :unstable => false } )
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ] ).not_to be_nil
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ].up? ).to be_true
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ].unstable? ).to be_false
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ][:up] ).to be_true
        expect( @c.links[ [0x1234, 42, 0x5678, 72] ][:unstable] ).to be_false

        expect( @c.switches[0x1234].links_out[ [0x1234, 42, 0x5678, 72] ] ).not_to be_nil
        expect( @c.switches[0x5678].links_in[ [0x1234, 42, 0x5678, 72] ] ).not_to be_nil
      end
    end

    describe "Port event" do
      before do
        @c = Map.new
        @c.add_switch Switch.new( {:dpid => 0x1234, :up => true } )
        @c.add_switch Switch.new( {:dpid => 0x5678, :up => true } )
      end

      it "should add Port on port up event" do
        @c.update_port( { :dpid => 0x1234, :portno => 42, :name => "Port Name", :mac => "FF:FF:FF:FF:FF:FF", :external => false, :up => true } )
        expect( @c.switches[0x1234].ports[42].up? ).to be_true
        expect( @c.switches[0x1234].ports[42].external? ).to be_false
        expect( @c.switches[0x1234].ports[42].name ).to eq("Port Name")
        expect( @c.switches[0x1234].ports[42].mac ).to eq("FF:FF:FF:FF:FF:FF")
      end

      it "should delete Port on port down event" do
        @c.update_port( { :dpid => 0x1234, :portno => 42, :name => "Port Name", :mac => "FF:FF:FF:FF:FF:FF", :external => false, :up => false } )
        expect( @c.switches[0x1234].ports ).not_to include(42)
      end

      it "should update Port on existing port up event" do
        @c.update_port( { :dpid => 0x1234, :portno => 42, :name => "Port Name", :mac => "FF:FF:FF:FF:FF:FF", :external => false, :up => true } )
        @c.update_port( { :dpid => 0x1234, :portno => 42, :name => "New Port Name", :external => false, :up => true } )
        expect( @c.switches[0x1234].ports[42].up? ).to be_true
        expect( @c.switches[0x1234].ports[42].external? ).to be_false
        expect( @c.switches[0x1234].ports[42].name ).to eq("New Port Name")
        expect( @c.switches[0x1234].ports[42].mac ).to eq("FF:FF:FF:FF:FF:FF")
      end
    end

    describe "Port event recoverable error" do
      before do
        @c = Map.new
      end
      it "should add Switch and Port on port up event, when switch did not exist" do
        @c.update_port( { :dpid => 0x1234, :portno => 42, :name => "Port Name", :mac => "FF:FF:FF:FF:FF:FF", :external => false, :up => true } )
        expect( @c.switches[0x1234].ports[42].up? ).to be_true
        expect( @c.switches[0x1234].ports[42].external? ).to be_false
        expect( @c.switches[0x1234].ports[42].name ).to eq("Port Name")
        expect( @c.switches[0x1234].ports[42].mac ).to eq("FF:FF:FF:FF:FF:FF")
      end
    end

    it "should be serializable to human readable form by to_s" do
      c = Map.new

      s = Switch.new( { :dpid => 0x1234, :up => true, :magic => 42 } )
      s.add_port Port.new( { :dpid => 0x1234, :portno => 42, :up => true, :not_used => 1 } )
      c.add_switch s
      c.add_link Link.new( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :not_used => 1, :up => true } )
      c.add_link Link.new( {:from_dpid => 0xABCD, :from_portno => 102, :to_dpid => 0x1234, :to_portno => 42, :not_used => 1, :up => true } )
      expect( c.to_s ).to be == <<-EOS
Map:
Switch: 0x1234 - {magic:42, up:true}
 Port: 0x1234:42 - {not_used:1, up:true}
 Links_in
  <= 0xabcd:102
 Links_out
  => 0x5678:72
Switch: 0xabcd - {up:true}
 Links_out
  => 0x1234:42
Switch: 0x5678 - {up:true}
 Links_in
  <= 0x1234:42
Link: (0xabcd:102)->(0x1234:42) - {not_used:1, up:true}
Link: (0x1234:42)->(0x5678:72) - {not_used:1, up:true}
      EOS
    end
  end

  describe "Map management functions" do
    before do
      class DummyController
        include Topology
      end
      @c = DummyController.new
    end

    it "should respond to get_last_map" do
      expect( @c ).to respond_to( :get_last_map )
    end

    it "should respond to get_map" do
      expect( @c ).to respond_to( :get_map )
    end

    it "should respond to map_ready?" do
      expect( @c ).to respond_to( :map_ready? )
    end

    it "should respond to map_up_to_date?" do
      expect( @c ).to respond_to( :map_up_to_date? )
    end

    it "should issue all status request on rebuild request" do

      expect( @c.map_up_to_date? ).to be_false

      @c.should_receive(:get_all_switch_status).and_yield( [ {:dpid => 0x1234, :up => true } ] )
      @c.should_receive(:get_all_port_status).and_yield( [ {:dpid => 0x1234, :portno => 42, :up => true } ] )
      @c.should_receive(:get_all_link_status).and_yield( [ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :up => true } ] )

      @c.should_receive(:map_ready).once

      @c.send_rebuild_map_request

      expect( @c.map_up_to_date? ).to be_true
    end

    it "should update Map on Switch update event" do
      @c.update_map_by_switch_hash( {:dpid => 0x1234, :up => true } )
      map = @c.get_last_map
      expect( map.lookup_switch_by_dpid( 0x1234 ) ).not_to be_nil

      @c.update_map_by_switch_hash( {:dpid => 0x1234, :up => false } )
      map = @c.get_last_map
      expect( map.lookup_switch_by_dpid( 0x1234 ) ).to be_nil
    end

    it "should update Map on Port update event" do
      @c.update_map_by_port_hash( {:dpid => 0x1234, :portno => 42, :up => true } )
      map = @c.get_last_map
      expect( map.lookup_switch_by_dpid( 0x1234 ).ports[42] ).not_to be_nil

      @c.update_map_by_port_hash( {:dpid => 0x1234, :portno => 42, :up => false } )
      map = @c.get_last_map
      expect( map.lookup_switch_by_dpid( 0x1234 ).ports[42] ).to be_nil
    end

    it "should update Map on Link update event" do
      @c.update_map_by_link_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :up => true } )
      map = @c.get_last_map
      expect( map.lookup_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ) ).not_to be_nil

      @c.update_map_by_link_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :up => false } )
      map = @c.get_last_map
      expect( map.lookup_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ) ).to be_nil
    end

  end
end

### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:

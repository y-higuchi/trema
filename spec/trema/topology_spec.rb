#
# Copyright (C) 2008-2012 NEC Corporation
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

  describe Port do
    it "should be initialized like Hash" do
      lambda {
        port = Port[ {:dpid => 0x1234, :portno => 42 } ]
      }.should_not raise_error
    end
    
    it "should raise error if empty instance is being created" do
      lambda {
        port = Port.new
      }.should raise_error()
    end
    
    it "should raise error if key :dpid missing" do
      lambda {
        port = Port[ {:data => 0x1234, :portno => 42 } ]
      }.should raise_error(ArgumentError)
    end
    
    it "should raise error if key :portno missing" do
      lambda {
        port = Port[ {:dpid => 0x1234, :number => 42 } ]
      }.should raise_error(ArgumentError)
    end
  
    it "should have dpid accessor" do
      port = Port[ {:dpid => 0x1234, :portno => 42 } ]
      port.dpid.should == 0x1234
    end
    
    it "should have portno accessor" do
      port = Port[ {:dpid => 0x1234, :portno => 42 } ]
      port.portno.should == 42
    end
    
    it "should have method key" do
      port = Port[ {:dpid => 0x1234, :portno => 42 } ]
      port.key.should == [0x1234,42]
    end
  
    it "should have method key_str" do
      port = Port[ {:dpid => 0x1234, :portno => 42 } ]
      port.key_str.should match("1234-42")
    end
    
    it "should be serializable to human readable form by to_s" do
      port = Port[ {:dpid => 0x1234, :portno => 42, :up => true } ]
      port.to_s.should == "Port 0x1234:42 - [[:up, true]]"
    end
  end
  
  
  describe Link do
    it "should be initialized like Hash" do
      lambda {
        link = Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72  } ]
      }.should_not raise_error
    end
    
    it "should raise error if empty instance is being created" do
      lambda {
        link = Link.new
      }.should raise_error()
    end
    
    it "should raise error if key :from_dpid missing" do
      lambda {
        link = Link[ {:from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ]
      }.should raise_error(ArgumentError)
    end
  
    it "should raise error if key :from_portno missing" do
      lambda {
        link = Link[ {:from_dpid => 0x1234, :to_dpid => 0x5678, :to_portno => 72 } ]
      }.should raise_error(ArgumentError)
    end
  
    it "should raise error if key :to_dpid missing" do
      lambda {
        link = Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_portno => 72 } ]
      }.should raise_error(ArgumentError)
    end
  
    it "should raise error if key :to_portno missing" do
      lambda {
        link = Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678 } ]
      }.should raise_error(ArgumentError)
    end
    
    it "should have from_dpid accessor" do
      link = Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ]
      link.from_dpid.should == 0x1234
    end
    
    it "should have from_dpid accessor" do
      link = Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ]
      link.from_portno.should == 42
    end
  
    it "should have to_dpid accessor" do
      link = Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ]
      link.to_dpid.should == 0x5678
    end
    
    it "should have to_dpid accessor" do
      link = Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ]
      link.to_portno.should == 72
    end
  
    it "should have method key" do
      link = Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ]
      link.key.should == [0x1234,42,0x5678,72]
    end
  
    it "should have method key_str" do
      link = Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ]
      link.key_str.should match("1234-42-5678-72")
    end
    
    it "should be serializable to human readable form by to_s" do
      link = Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :up => true } ]
      link.to_s.should == "Link (0x1234:42)->(0x5678:72) - [[:up, true]]"
    end
  end
  
  
  describe Switch do
    it "should be initialized like Hash" do
      lambda {
        s = Switch[ {:dpid => 0x1234 } ]
      }.should_not raise_error
    end
    
    it "should raise error if empty instance is being created" do
      lambda {
        s = Switch.new
      }.should raise_error()
    end
    
    it "should raise error if key :dpid missing" do
      lambda {
        s = Switch[ { :portno => 42 } ]
      }.should raise_error(ArgumentError)
    end
  
    it "should have dpid accessor" do
      s = Switch[ { :dpid => 0x1234, :magic => 42 } ]
      s.dpid.should == 0x1234
    end
    
    it "should have method key" do
      s = Switch[ { :dpid => 0x1234, :magic => 42 } ]
      s.key.should == 0x1234
    end
  
    it "should have method key_str" do
      s = Switch[ { :dpid => 0x1234, :magic => 42 } ]
      s.key_str.should match("1234")
    end
    
    
    it "should have port manipulation methods" do
      s = Switch[ { :dpid => 0x1234, :magic => 42 } ]
      
      s.add_port Port[ { :dpid => 0x1234, :portno => 1 } ]
      s.ports[1].should_not be_nil
      
      s.add_port_by_portno 2
      s.ports[2].should_not be_nil
  
      s.update_port_by_hash( { :dpid => 0x1234, :portno => 3, :up => true } )
      s.ports[3].should_not be_nil
      
      s.del_port Port[ { :dpid => 0x1234, :portno => 2 } ]
      s.ports[2].should be_nil
  
      s.del_port_by_portno 3
      s.ports[3].should be_nil
      
      s.update_port_by_hash( { :dpid => 0x1234, :portno => 1, :up => false } )
      s.ports[1].should be_nil
    end
    
    it "should have link manipulation methods" do
      s1 = Switch[ { :dpid => 0x1234, :magic => 42 } ]
      s2 = Switch[ { :dpid => 0x5678, :magic => 42 } ]
      
      l1 = Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ]
      l2 = Link[ {:from_dpid => 0x5678, :from_portno => 72, :to_dpid => 0x1234, :to_portno => 42 } ]
      
      s1.add_outbound_link l1
      s1.links_out.empty?.should_not be_true
      s2.add_inbound_link l1
      s2.links_in.empty?.should_not be_true
      
      s1.add_inbound_link l2
      s1.links_in.empty?.should_not be_true
      s2.add_outbound_link l2
      s2.links_out.empty?.should_not be_true
      
      s1.del_inbound_link l2
      s1.del_outbound_link l1
      s1.links_in.empty?.should be_true
      s1.links_out.empty?.should be_true
      
      s2.del_link_by_key l1.key
      s2.del_link_by_key l2.key
      s2.links_in.empty?.should be_true
      s2.links_out.empty?.should be_true
    end
    
    it "should be serializable to human readable form by to_s" do
      s = Switch[ { :dpid => 0x1234, :magic => 42 } ]
      s.add_port Port[ { :dpid => 0x1234, :portno => 42, :up => true } ]
      s.add_outbound_link Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :not_used => 1 } ]
      s.add_inbound_link Link[ {:from_dpid => 0xABCD, :from_portno => 102, :to_dpid => 0x1234, :to_portno => 42, :not_used => 1 } ]
      s.to_s.should == <<-EOS
Switch 0x1234 - [[:magic, 42]]
 Port 0x1234:42 - [[:up, true]]
 Links_in
  <= 0xabcd:102
 Links_out
  => 0x5678:72
      EOS
    end
  
  end
  
  describe Cache do
    it "should initialize it's members to empty" do
      c = Cache.new
      c.switches.empty?.should be_true
      c.links.empty?.should be_true
    end
    
    it "should have switch manipulation methods" do
      c = Cache.new
      c.add_switch Switch[ {:dpid => 0x1234 } ]
      c.switches.empty?.should be_false
      
      c.lookup_switch_by_dpid( 0x1234 ).should_not be_nil
      
      c.add_switch Switch[ {:dpid => 0x5678 } ]
      c.switches[ 0x5678 ].should_not be_nil
        
      c.del_switch Switch[ {:dpid => 0x5678 } ]
      c.del_switch_by_dpid 0x1234
      c.switches.empty?.should be_true
    end
    
    it "should have link manipulation methods" do
      c = Cache.new
      c.add_switch Switch[ {:dpid => 0x1234 } ]
      c.add_switch Switch[ {:dpid => 0x5678 } ]
      
      c.add_link Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ]
      c.links.empty?.should be_false
      
      c.lookup_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ).should_not be_nil
      
      c.del_link Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ]
      c.lookup_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ).should be_nil
        
      c.add_link Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ]
      c.del_link_by_key_elements 0x1234, 42, 0x5678, 72
      c.lookup_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ).should be_nil
        
      c.add_link Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ]
      c.del_link_by_key_tuple [0x1234, 42, 0x5678, 72]
      c.lookup_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ).should be_nil
        
      c.links.empty?.should be_true
    end
    
    describe "Switch events" do
      it "should add Switch on switch up event" do
        c = Cache.new 
        c.update_switch_by_hash( {:dpid => 0x1234, :status => 1, :up => true } ) 
        c.switches.should include(0x1234)
        
        c.switches[ 0x1234 ][:status].should == 1
        c.switches[ 0x1234 ][:up].should be_true
      end
      
      it "should delete Switch on switch up event" do
        c = Cache.new 
        c.add_switch Switch[ {:dpid => 0x1234, :status => 1, :up => true } ]
        c.add_switch Switch[ {:dpid => 0x5678, :status => 1, :up => true } ]
    
        c.update_switch_by_hash( {:dpid => 0x1234, :status => 0, :up => false } ) 
        c.switches.should_not include(0x1234)
        c.switches.should include(0x5678)
      end
      
      it "should update Switch on existing switch's up event" do
        c = Cache.new 
        c.add_switch Switch[ {:dpid => 0x1234, :status => 1, :up => true, :extra => "Old Value", :no_change => true } ]
        c.update_switch_by_hash( {:dpid => 0x1234, :status => 1, :up => true, :extra => "New Value" } )
        c.switches.should include(0x1234)
        c.switches[ 0x1234 ][:status].should == 1
        c.switches[ 0x1234 ][:up].should be_true
        c.switches[ 0x1234 ][:extra].should match("New Value")
        c.switches[ 0x1234 ][:no_change].should be_true
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
        @c.links[ [0x1234, 42, 0x5678, 72] ].should_not be_nil
        @c.links[ [0x1234, 42, 0x5678, 72] ][:status].should == 0
        @c.links[ [0x1234, 42, 0x5678, 72] ][:up].should be_true
        @c.links[ [0x1234, 42, 0x5678, 72] ][:unstable].should be_false
        
        @c.switches[0x1234].links_out[ [0x1234, 42, 0x5678, 72] ].should_not be_nil
        @c.switches[0x5678].links_in[ [0x1234, 42, 0x5678, 72] ].should_not be_nil
      end
      
      it "should remove Link on link down event" do
        @c.add_link Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ]
        @c.links.empty?.should be_false
        
        @c.update_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :status => 1, :up => false, :unstable => false } )
        @c.links[ [0x1234, 42, 0x5678, 72] ].should be_nil
      end
      
      it "should update Link on existing link event" do
        @c.update_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :status => 1, :up => true, :unstable => false } )
          
        @c.update_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :up => true, :unstable => true } )
        @c.links[ [0x1234, 42, 0x5678, 72] ].should_not be_nil
        @c.links[ [0x1234, 42, 0x5678, 72] ][:status].should == 1
        @c.links[ [0x1234, 42, 0x5678, 72] ][:up].should be_true
        @c.links[ [0x1234, 42, 0x5678, 72] ][:unstable].should be_true
        
        @c.switches[0x1234].links_out[ [0x1234, 42, 0x5678, 72] ].should_not be_nil
        @c.switches[0x5678].links_in[ [0x1234, 42, 0x5678, 72] ].should_not be_nil
      end
    end
    
    describe "Link event recoverable error" do
      before do
        @c = Cache.new
      end
      it "should add Switch and Link on link up event, when switch did not exist" do
            @c.update_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :status => 0, :up => true, :unstable => false } )
            @c.links[ [0x1234, 42, 0x5678, 72] ].should_not be_nil
            @c.links[ [0x1234, 42, 0x5678, 72] ][:status].should == 0
            @c.links[ [0x1234, 42, 0x5678, 72] ][:up].should be_true
            @c.links[ [0x1234, 42, 0x5678, 72] ][:unstable].should be_false
            
            @c.switches[0x1234].links_out[ [0x1234, 42, 0x5678, 72] ].should_not be_nil
            @c.switches[0x5678].links_in[ [0x1234, 42, 0x5678, 72] ].should_not be_nil
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
        @c.switches[0x1234].ports[42][:name].should match("Port Name")
      end
      
      it "should delete Port on port down event" do
        @c.update_port_by_hash( { :dpid => 0x1234, :portno => 42, :name => "Port Name", :mac => "FF:FF:FF:FF:FF:FF", :external => 0, :status => 1, :up => false } )
        @c.switches[0x1234].ports.should_not include(42)
      end
      
      it "should update Port on existing port up event" do
        @c.update_port_by_hash( { :dpid => 0x1234, :portno => 42, :name => "Port Name", :mac => "FF:FF:FF:FF:FF:FF", :external => 0, :status => 0, :up => true } )
        @c.update_port_by_hash( { :dpid => 0x1234, :portno => 42, :name => "New Port Name", :external => 0, :status => 0, :up => true } )
        @c.switches[0x1234].ports[42][:name].should match("Port Name")
        @c.switches[0x1234].ports[42][:mac].should match("FF:FF:FF:FF:FF:FF")
      end
    end
    
    describe "Port event recoverable error" do
      before do
        @c = Cache.new
      end
      it "should add Switch and Port on port up event, when switch did not exist" do
        @c.update_port_by_hash( { :dpid => 0x1234, :portno => 42, :name => "Port Name", :mac => "FF:FF:FF:FF:FF:FF", :external => 0, :status => 0, :up => true } )
        @c.switches[0x1234].ports[42][:name].should match("Port Name")
      end
    end
    
    it "should be serializable to human readable form by to_s" do
      c = Cache.new
      c.add_switch Switch[ { :dpid => 0x1234, :magic => 42 } ]
      c.add_link Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :not_used => 1 } ]
      c.add_link Link[ {:from_dpid => 0xABCD, :from_portno => 102, :to_dpid => 0x1234, :to_portno => 42, :not_used => 1 } ]
      c.to_s.should == <<-EOS
[Topology Cache]
Switch 0x1234 - [[:magic, 42]]
 Links_in
  <= 0xabcd:102
 Links_out
  => 0x5678:72
Switch 0xabcd - []
 Links_out
  => 0x1234:42
Switch 0x5678 - []
 Links_in
  <= 0x1234:42
Link (0xabcd:102)->(0x1234:42) - [[:not_used, 1]]
Link (0x1234:42)->(0x5678:72) - [[:not_used, 1]]
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
      @c.should respond_to( :get_cache, :cache_ready?, :cache_up_to_date? )
    end
    
    it "should issue all status request on rebuild request" do
      
      @c.cache_up_to_date?.should be_false
      
      @c.should_receive(:send_all_switch_status_request).and_yield( [ {:dpid => 0x1234, :up => true } ] )
      @c.should_receive(:send_all_port_status_request).and_yield( [ {:dpid => 0x1234, :portno => 42, :up => true } ] )
      @c.should_receive(:send_all_link_status_request).and_yield( [ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :up => true } ] )
      
      @c.should_receive(:cache_ready).once
      
      @c.send_rebuild_cache_request
      
      @c.cache_up_to_date?.should be_true
    end
    
    it "should update Cache on Switch update event" do
      @c.update_cache_by_switch_hash( {:dpid => 0x1234, :up => true } )
      cache = @c.get_cache
      cache.lookup_switch_by_dpid( 0x1234 ).should_not be_nil 

      @c.update_cache_by_switch_hash( {:dpid => 0x1234, :up => false } )
      cache = @c.get_cache
      cache.lookup_switch_by_dpid( 0x1234 ).should be_nil 
    end
    
    it "should update Cache on Port update event" do
      @c.update_cache_by_port_hash( {:dpid => 0x1234, :portno => 42, :up => true } )
      cache = @c.get_cache
      cache.lookup_switch_by_dpid( 0x1234 ).ports[42].should_not be_nil

      @c.update_cache_by_port_hash( {:dpid => 0x1234, :portno => 42, :up => false } )
      cache = @c.get_cache
    cache.lookup_switch_by_dpid( 0x1234 ).ports[42].should be_nil
    end
    
    it "should update Cache on Link update event" do
      @c.update_cache_by_link_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :up => true } )
      cache = @c.get_cache
      cache.lookup_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ).should_not be_nil 

      @c.update_cache_by_link_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72, :up => false } )
      cache = @c.get_cache
      cache.lookup_link_by_hash( {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ).should be_nil 
    end
    
    
  end
end

### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:

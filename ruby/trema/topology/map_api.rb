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

require 'trema/topology'
require 'trema/topology/map'
require 'trema/topology/guarded-property-accessor'


module Trema
  
  module Topology
    class Switch
      include Topology::GuardedPropertyAccesor

      # @!group Additional methods for Map maintenance

      # @return [Hash] Raw access to properties of a Switch. User must not modify mandatory key elements in Hash.
      attr_reader :property


      # @return [String] Switch key as a String
      def key_str
        return "S#{ dpid.to_s(16) }"
      end


      # @!attribute [w] up
      #   @param [Boolean] new_state_up
      #   @return [Boolean] returns new state
      def up= new_state_up
        if new_state_up then
          @property[:up] = true
        else
          @property[:up] = false
        end
      end


      # Update port on this switch
      # @overload update_port port
      #   @param [Port] port Port instance to update
      # @overload update_port port_hash
      #   @param [Hash] port_hash a Hash with port info about instance to update
      #   @option (see Port#initialize)
      def update_port port
        port = port.property if port.is_a?(Port)
        raise ArgumentError, "Mandatory key element for Port missing in Hash" if not Port.has_mandatory_keys?( port )

        portno = port[:portno]
        if port[:up] then
          if @ports.include?( portno ) then
            @ports[ portno ].update port
          else
            add_port Port.new( port )
          end
        else
          @ports.delete( portno )
        end
      end
    end
    
    class Port
      include Topology::GuardedPropertyAccesor

      # @!group Additional methods for Map maintenance

      # @return [Hash] Raw access to properties of a Port. User must not modify mandatory key elements in Hash.
      attr_reader :property


      # @return [String] Port key as a String
      def key_str
        return "P#{ dpid.to_s(16) }-#{ portno.to_s }"
      end
    end
    
    class Link
      include Topology::GuardedPropertyAccesor

      # @!group Additional methods for Map maintenance

      # @return [Hash] Raw access to properties of a Link. User must not modify mandatory key elements in Hash.
      attr_reader :property


      # @return [String] Link key as a String
      def key_str
        return "L#{ from_dpid.to_s(16) }-#{ from_portno.to_s }-#{ to_dpid.to_s(16) }-#{ to_portno.to_s }"
      end
    end
  end
  
  # Module to add Topology Map feature
  module TopologyMap
    include Topology
    
    #
    # @private Just a placeholder for YARD.
    #
    def self.handler name
      # Do nothing.
    end

    # @!group Basic Map events and methods
    #
    # @example
    #  class TestController < Controller
    #    include Topology
    #
    #    oneshot_timer_event :on_start, 0
    #    def on_start
    #      send_enable_topology_discovery
    #      send_rebuild_map_request
    #    end
    #
    #    def map_ready map
    #      info "Topology Map ready!"
    #      p map
    #
    #      # You can do whatever with map after this point.
    #      # Topology::Map instance can also be obtained later using #get_map method.
    #
    #      # example:
    #      # build spanning trees for each vertices
    #    end
    #
    #    def link_status_updated link
    #      # Directly read Hash containing link info.
    #      p link[:from_dpid]
    #      # Or, create Topology::Link instance.
    #      linkObj = Link.new( links )
    #      p linkObj.from_dpid
    #
    #      # Do what ever before Topology Map update
    #      # Note: Link instance will be removed after map update, 
    #      #       if the notified link state was not up.
    #
    #      # example:
    #      if not linkObj.up? then
    #        # Link down event:
    #        # 1. drop flow path, which contains this link.
    #        # 2. resolve alternate path with updated topology.
    #        # 3. set newly calculated flow path.
    #      else
    #        # Link up event:
    #        # 1. PathResolver rebuild spanning trees.
    #        # 2. replace existing path  by newly calculated path using using FlowManager::libPath?
    #      end
    #
    #      # (Optional) Manually update Map
    #      # Note: Map will be automatically updated after exit from this handler
    #      #       even if this manual update
    #      update_map_by_link_hash link
    #
    #      if map_ready?
    #        # Check to see if we're at a point after map_ready event.
    #
    #        # Do whatever with updated map.
    #        puts get_map
    #      end
    #    end
    #  end
    #
    # Start rebuilding topology map.
    # `map_ready` or specified block will be called, when map rebuild is complete.
    # @param [Boolean] clear_map Clear map before update.
    # @yieldparam map [Map]  Current map
    # @return [Boolean] true if request sent successfully
    def send_rebuild_map_request clear_map=true, &block
      @need_map_ready_notify = true
      @map_up_to_date = false
      @map = Map.new if clear_map
      @all_link_received = false
      @all_switch_received = false
      @all_port_received = false

      succ = true
      succ &= get_all_switch_status do |switches|
        switches.each { |sw| update_map_by_switch_hash(sw) }
        @all_switch_received = true
        notify_map_ready( &block ) if @need_map_ready_notify and map_ready?
      end

      succ &= get_all_port_status do |ports|
        ports.each { |port| update_map_by_port_hash(port) }
        @all_port_received = true
        notify_map_ready( &block ) if @need_map_ready_notify and map_ready?
      end

      succ &= get_all_link_status do |links|
        links.each { |link| update_map_by_link_hash(link) }
        @all_link_received = true
        notify_map_ready( &block ) if @need_map_ready_notify and map_ready?
      end
      return succ
    end


    #
    # @!method map_ready( map )
    # Event handler for map_ready event.
    # @abstract map_ready event handler. Override this to implement a custom handler.
    # @param [Map] map
    # @return [void]
    #   Reference to current topology map.
    # @see #send_rebuild_map_request See #send_rebuild_map_request for usage example.
    handler :map_ready

    
    #
    # Returns a reference to latest map available.
    # @note Returned instance may be outdated, when invoked inside Topology update event handlers
    # before manually update of the map.
    # @return [Map] Returns a reference to available map.
    #
    # @see #get_map
    #
    def get_last_map
      return @map
    end
    
    #
    # Returns a reference to current map when available.
    # @note This method will return nil when a updated map is not ready.
    # @return [Map] Returns a reference to latest map or nil, when current map is not available.
    #
    # @example
    #  def link_status_updated lnk
    #    get_last_map  # returns a outdated network map.
    #    get_map       # returns nil
    #    update_map_by_link_hash lnk
    #    get_last_map  # returns the current map
    #    get_map       # returns the current map
    #  end
    #
    def get_map
      return @map if map_up_to_date?
      return nil
    end


    # Check if map is ready to use.
    def map_ready?
      @all_link_received and @all_switch_received and @all_port_received
    end


    # Check if current map is in latest state.
    def map_up_to_date?
      map_ready? and @map_up_to_date
    end


    # Call inside switch_status_updated handler to manually update map to latest state
    # @note Map will be automatically updated even if this method call was omitted.
    # @param [Hash] sw Specify switch hash given to switch_status_updated. Additional properties may be added to reflect internal map.
    # @return [void]
    # @see #send_rebuild_map_request See #send_rebuild_map_request for usage example.
    def update_map_by_switch_hash sw
      @map ||= Topology::Map.new
      @map.update_switch( sw )
      @map_up_to_date = true
    end


    # Call inside link_status_updated handler to manually update map to latest state
    # @note Map will be automatically updated even if this method call was omitted.
    # @param [Hash] link Specify link hash given to link_status_updated. Additional properties may be added to reflect internal map.
    # @return [void]
    # @see #send_rebuild_map_request See #send_rebuild_map_request for usage example.
    def update_map_by_link_hash link
      @map ||= Topology::Map.new
      @map.update_link( link )
      @map_up_to_date = true
    end


    # Call inside port_status_updated handler to manually update map to latest state
    # @note Map will be automatically updated even if this method call was omitted.
    # @param [Hash] port Specify link hash given to port_status_updated. Additional properties may be added to reflect internal map.
    # @return [void]
    # @see #send_rebuild_map_request See #send_rebuild_map_request for usage example.
    def update_map_by_port_hash port
      @map ||= Topology::Map.new
      @map.update_port( port )
      @map_up_to_date = true
    end

    ######################
    protected
    ######################


    alias_method :super_switch_status_updated, :_switch_status_updated
    def _switch_status_updated sw
      super_switch_status_updated( sw )
      update_map_by_switch_hash( sw )
    end


    alias_method :super_port_status_updated, :_port_status_updated
    def _port_status_updated port
      super_port_status_updated( port )
      update_map_by_port_hash( port )
    end


    alias_method :super_link_status_updated, :_link_status_updated
    def _link_status_updated link
      super_link_status_updated( link )
      update_map_by_link_hash( link )
    end


    def notify_map_ready &block
      if block then
        block.call( @map )
      elsif self.respond_to? :map_ready then
        map_ready @map
      end
      @need_map_ready_notify = false
    end
  end
end


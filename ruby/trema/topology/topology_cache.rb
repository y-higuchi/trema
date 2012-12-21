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


require 'trema/topology/port'
require 'trema/topology/link'
require 'trema/topology/switch'
require 'trema/topology/cache'


module Trema
  module Topology
    # Link's Hash key 4-tuple's array index 
    FROM_DPID = 0
    # Link's Hash key 4-tuple's array index 
    FROM_PORTNO = 1
    # Link's Hash key 4-tuple's array index 
    TO_DPID = 2
    # Link's Hash key 4-tuple's array index 
    TO_PORTNO = 3
  end
  
  # A module to add topology information notification and cached topology capability to Controller
  #
  # @example
  #  class TestController < Controller
  #    include Topology
  #  
  #    def topology_ready
  #      info "Topology ready!"
  #      # enable link discovery after topology is ready
  #      enable_topology_discovery
  #    end
  #  
  #    def topology_discovery_ready
  #      info "Discovery ready!"
  #      # enable cache after link discovery is ready
  #      send_rebuild_cache_request
  #    end
  #    
  #    def cache_ready cache
  #      info "Topology Cache ready!"
  #      p cache
  #
  #      # You can do whatever with cache after this point.
  #      # Topology::Cache instance can also be obtained later using #get_cache method.
  #
  #      # example:
  #      # build spanning trees for each vertices
  #    end
  #    
  #    def link_status_updated link
  #      # Directly read Hash containing link info.  
  #      p link[:from_dpid]
  #      # Or, create Topology::Link instance.
  #      linkObj = Link[ links ]
  #      p linkObj.from_dpid
  #      
  #      # Do what ever before Topology Cache update
  #      # Note: Link instance will be removed after cache update, if the state
  #      #       was not up.
  #
  #      # example:
  #      if not link[:up] then
  #        # Link down event:
  #        # 1. drop path, which contains this link using FlowManager::libPath.
  #        # 2. PathResolver rebuild spanning trees.
  #        # 3. set newly calculated path using using FlowManager::libPath.
  #      else
  #        # Link up event:
  #        # 1. PathResolver rebuild spanning trees.
  #        # 2. replace existing path  by newly calculated path using using FlowManager::libPath?
  #      end 
  #
  #      # (Optional) Manually update Cache
  #      # Note: Cache will be automatically updated after exit from this handler
  #      #       even if this manual update 
  #      update_cache_by_link_hash link
  #      
  #      if cache_ready?
  #        # Check to see if we're at a point after cache_ready event.
  #
  #        # Do whatever with updated cache.
  #        puts get_cache
  #      end
  #    end
  #  end
  #
  module Topology
    
    #
    # @private Just a placeholder for YARD.
    #
    def self.handler name
      # Do nothing.
    end
    
    # @group Basic Cache events and methods
    
    # Returns a reference to current cache
    def get_cache
      @cache
    end
    
    # Check if cache is ready to use.
    def cache_ready?
      @all_link_received and @all_switch_received and @all_port_received
    end
    
    #
    # @!method cache_ready( cache )
    # Event handler for cache_ready event.
    # @abstract cache_ready event handler. Override this to implement a custom handler.
    # @param [Cache] cache
    #   Reference to current topology cache. 
    handler :cache_ready
    
    # 
    # Start rebuilding topology cache.
    # cache_ready will be called, when cache rebuild is complete
    # @param [Boolean] clear_cache Clear cache before update.
    def send_rebuild_cache_request clear_cache=true
      @need_cache_ready_notify = true
      @cache_up_to_date = false
      @cache = Topology::Cache.new if clear_cache
      @all_link_received = false
      @all_switch_received = false
      @all_port_received = false
      
      send_all_switch_status_request do |switches|
        switches.each { |e| update_cache_by_switch_hash(e) }
        @all_switch_received = true
        notify_cache_ready() if @need_cache_ready_notify and cache_ready?
      end
      send_all_port_status_request do |ports|
        ports.each { |e| update_cache_by_port_hash(e) }
        @all_port_received = true
        notify_cache_ready() if @need_cache_ready_notify and cache_ready?
      end
      send_all_link_status_request do |links|
        links.each { |e| update_cache_by_link_hash(e) }
        @all_link_received = true
        notify_cache_ready() if @need_cache_ready_notify and cache_ready?
      end
    end
    
    # Check if current cache is in latest state.
    def cache_up_to_date?
      cache_ready? and @cache_up_to_date
    end

    # @group Cache manual update operations
    
    # Call inside switch_status_updated handler to manually update cache to latest state
    # @note Cache will be automatically updated even if this method call was omitted.
    def update_cache_by_switch_hash sw
      _switch_status_updated sw
    end

    # Call inside link_status_updated handler to manually update cache to latest state
    # @note Cache will be automatically updated even if this method call was omitted.
    def update_cache_by_link_hash link
      _link_status_updated link
    end

    # Call inside port_status_updated handler to manually update cache to latest state
    # @note Cache will be automatically updated even if this method call was omitted.
    def update_cache_by_port_hash port
      _port_status_updated port
    end
    
    ######################
    protected
    ######################
    def _switch_status_updated sw
      @cache = Topology::Cache.new if not @cache
      @cache.update_switch_by_hash( sw )
      @cache_up_to_date = true
    end

    def _port_status_updated port
      @cache = Topology::Cache.new if not @cache
      @cache.update_port_by_hash( port )
      @cache_up_to_date = true
    end

    def _link_status_updated link
      @cache = Topology::Cache.new if not @cache
      @cache.update_link_by_hash( link )
      @cache_up_to_date = true
    end

    # @private 
    def notify_cache_ready
      if self.respond_to? :cache_ready then
        cache_ready @cache
      end
      @need_cache_ready_notify = false
    end
  end
end


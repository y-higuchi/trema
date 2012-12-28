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

require 'trema/topology/port'
require 'trema/topology/link'
require 'trema/topology/switch'

module Trema
  
  module Topology
    
    #
    # @private Just a placeholder for YARD.
    #
    def self.handler name
      # Do nothing.
    end
    
    # @group Basic Topology events and methods
    
    #
    # @!method topology_ready?
    # @return true if Topology service is ready to use.
    #
    def topology_ready?
      @is_topology_ready
    end
    
    
    #
    # @!method topology_ready(  )
    #
    # @abstract topology_ready event handler. Override this to implement a custom handler.
    # Start using Topology service related methods after this event. 
    #
    handler :topology_ready
    
    #
    # @!method topology_discovery_ready(  )
    #
    # @abstract topology_discovery_ready event handler. Override this to implement a custom handler.
    #
    # Start using Topology Discovery service related methods after this event. 
    #
    handler :topology_discovery_ready

    # @group Topology update event handlers

    #
    # @!method switch_status_updated( sw_stat )
    #
    # @abstract switch_status_updated event handler. Override this to implement a custom handler.
    #
    # @param [Hash] sw_stat
    #   Hash containing info about updated switch.
    # @option sw_stat [Integer] :dpid dpid of the switch
    # @option sw_stat [Integer] :status status of the switch. Refer to enum topology_switch_status_type in topology_service_interface.h
    # @option sw_stat [Boolean] :up true if status is TD_SWITCH_UP
    #
    handler :switch_status_updated

    #
    # @!method port_status_updated( port_stat )
    #
    # @abstract port_status_updated event handler. Override this to implement a custom handler.
    #
    # @param [Hash] port_stat
    #   Hash containing info about updated port.
    # @option port_stat [Integer] :dpid dpid of the switch
    # @option port_stat [Integer] :portno port number. Note that attribute name differ from C structs.
    # @option port_stat [String] :name name of the port
    # @option port_stat [String] :mac mac address
    # @option port_stat [Integer] :external external flag of the port. Refer to enum topology_port_external_type in topology_service_interface.h
    # @option port_stat [Integer] :status status of the port. Refer to enum topology_port_status_type in topology_service_interface.h
    # @option port_stat [Boolean] :up true if status is TD_PORT_UP
    #
    handler :port_status_updated
    
    #
    # @!method link_status_updated( link_stat )
    #
    # @abstract link_status_updated event handler. Override this to implement a custom handler.
    #
    # @param [Hash] link_stat
    #   Hash containing info about updated link.
    # @option link_stat [Integer] :from_dpid dpid of the switch which the link departs
    # @option link_stat [Integer] :from_portno port number of the switch which the link departs
    # @option link_stat [Integer] :to_dpid dpid of the switch which the link arraives
    # @option link_stat [Integer] :to_portno port number of the switch which the link arrives
    # @option link_stat [Integer] :status status of the link. Refer to enum topology_link_status_type in topology_service_interface.h
    # @option link_stat [Boolean] :up true if status is *NOT* TD_LINK_DOWN, false otherwise.
    # @option link_stat [Boolean] :unstable true if status is TD_LINK_UNSTABLE, false otherwise.
    #
    handler :link_status_updated
    
    # @group Get all status event handlers
    
    #
    # @!method all_switch_status_reply( sw_stats )
    # Event handler used for send_all_switch_status_request reply event,
    # if handler block was omitted on send_all_port_status_request call.
    # @abstract get_all_switch_status callback handler. Override this to implement a custom handler.
    #
    # @param [Array<Hash>] sw_stats
    #   Array of Hash containing info about updated switch.
    # @see #switch_status_updated Each Hash instance included in the array is equivalent to #switch_status_updated argument Hash.
    #
    handler :all_switch_status_reply

    #
    # @!method all_port_status_reply( port_stats )
    # Event handler used for send_all_port_status_request reply event,
    # if handler block was omitted on send_all_port_status_request call.
    # @abstract get_all_port_status callback handler. Override this to implement a custom handler.
    #
    # @param [Array<Hash>] port_stats
    #   Array of Hash containing info about updated port.
    # @see #port_status_updated Each Hash instance included in the array is equivalent to port_status_updated argument Hash.
    #
    handler :all_port_status_reply

    #
    # @!method all_link_status_reply( link_stat )
    # Event handler used for send_all_link_status_request reply event, 
    # if handler block was omitted on send_all_link_status_request call.
    # @abstract get_all_link_status call handler. Override this to implement a custom handler.
    #
    # @param [Array<Hash>] link_stat
    #   Array of Hash containing info about updated link.
    # @see #link_status_updated Each Hash instance included in the array is equivalent to link_status_updated argument Hash.
    #
    handler :all_link_status_reply
    
    # @endgroup
    
    #
    # @!method start
    # Initialize and subscribe to topology interface.
    # Place to implement initialization before start_trema() call.
    #
    # This method will be implicitly called inside Controller#run! between init_trema() and start_trema() calls if not overridden by user.
    # @note Be sure to initialize and subscribe to topology if overriding this method.
    #
    # @example
    #  class MyController < Controller
    #    include Topology
    #    def start
    #      init_libtopology "topology"
    #      subscribe_topology
    #      # Simply calling super() instead of above may be sufficient
    #
    #      # your application's pre-start_trema() call initialization here.
    #    end
    #  end
    #
    def start
      #  specify the name of topology service name
      init_libtopology "topology"
      subscribe_topology
    end
    
    #
    # @!method shutdown!
    #  Shutdown controller.
    #  Unsubscribe and finalize topology before stopping trema.  
    #
    def shutdown!
      unsubscribe_topology
      finalize_libtopology
      super()
    end
  end
end

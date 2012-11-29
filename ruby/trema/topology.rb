require "trema/controller"

module Trema
  # module to add topology information notification handlers to Controller
  module Topology
    
    #
    # @private Just a placeholder for YARD.
    #
    def self.handler name
      # Do nothing.
    end
    
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
    # Topology service related methods should be called after this event. 
    #
    handler :topology_ready
    
    #
    # @!method switch_status_updated( sw_stat )
    #
    # @abstract switch_status_updated event handler. Override this to implement a custom handler.
    #
    # @param [Hash] sw_stat
    #   Hash containing info about updated switch.
    # TODO Add param description
    #
    handler :switch_status_updated

    #
    # @!method port_status_updated( port_stat )
    #
    # @abstract port_status_updated event handler. Override this to implement a custom handler.
    #
    # @param [Hash] port_stat
    #   Hash containing info about updated port.
    # TODO Add param description
    #
    handler :port_status_updated
    
    #
    # @!method link_status_updated( link_stat )
    #
    # @abstract link_status_updated event handler. Override this to implement a custom handler.
    #
    # @param [Hash] link_stat
    #   Hash containing info about updated link.
    # TODO Add param description
    #
    handler :link_status_updated
    
    #
    # @!method all_switch_status_reply( sw_stats )
    #
    # @abstract get_all_switch_status callback handler. Override this to implement a custom handler.
    #
    # @param [Array<Hash>] sw_stats
    #   Array of Hash containing info about updated switch.
    # TODO Add param description
    #
    handler :all_switch_status_reply

    #
    # @!method all_port_status_reply( port_stats )
    #
    # @abstract get_all_port_status callback handler. Override this to implement a custom handler.
    #
    # @param [Array<Hash>] port_stats
    #   Array of Hash containing info about updated port.
    # TODO Add param description
    #
    handler :all_port_status_reply

    #
    # @!method all_link_status_reply( link_stat )
    #
    # @abstract get_all_link_status call handler. Override this to implement a custom handler.
    #
    # @param [Array<Hash>] link_stat
    #   Array of Hash containing info about updated link.
    # TODO Add param description
    #
    handler :all_link_status_reply
    
    #
    # @!method topology_discovery_ready(  )
    #
    # @abstract topology_discovery_ready event handler. Override this to implement a custom handler.
    #
    # Topology Discovery service related methods should be called after this event. 
    #
    handler :topology_discovery_ready
    
    #
    # @!method start
    # Initialization before start_trema() call.
    # Initialize and subscribe to topology interface.
    # This method will be implicitly called inside Controller#run! between init_trema() and start_trema() calls.
    # @note Be sure to initialize and subscribe to topology if overriding this method.
    #
    # @example
    #  class MyController < Controller
    #    include Topology
    #    def start
    #      super()
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
    # @overload shutdown!
    #  Shutdown controller.
    #  unsubscribe and finalize topology before stopping trema.  
    #
    def shutdown!
      unsubscribe_topology
      finalize_libtopology
      super()
    end
  end
end

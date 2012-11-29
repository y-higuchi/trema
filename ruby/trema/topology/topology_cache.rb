
module Trema
  module Topology
    
    # Link Hash key 4-tuple's array index
    FROM_DPID = 0
    # Link Hash key 4-tuple's array index
    FROM_PORTNO = 1
    # Link Hash key 4-tuple's array index
    TO_DPID = 2
    # Link Hash key 4-tuple's array index
    TO_PORTNO = 3
    
    class Port
      attr_reader :dpid, :portno
      attr_reader :attributes

      # @param [Hash] h Hash containing Port properties. Elements not listed in Options will be added to @attributes 
      # @option h [Integer] :dpid Switch dpid which this port belongs
      # @option h [Integer] :portno port number
      def initialize( h )
        raise ArgumentError, "Key element for Port missing in Hash" if h.values_at(:dpid, :portno).include? nil
        
        @attributes = Hash.new
        @dpid = h[:dpid]
        @portno = h[:portno]
        update_attributes( h )
        @dpid.freeze
        @portno.freeze 
      end

      # @param [Hash] h Hash containing Port attributes. Elements listed in Options will be ignored.
      # @option (see #initialize)
      def update_attributes( h )
        h.each_pair do |k,v|
          next if k == :dpid or k == :portno
          @attributes[k] = v
        end
      end

      def to_s
        "Port 0x#{@dpid.to_s(16)}:#{@portno.to_s} - #{@attributes.inspect}"
      end
    end
    
    class Link
      attr_reader :from_dpid, :from_portno, :to_dpid, :to_portno
      attr_reader :attributes
      
      # @param [Hash] h Hash containing Link properties. Elements not listed in Options will be added to @attributes
      # @option h [Integer] :from_dpid Switch dpid which this link departs from
      # @option h [Integer] :from_portno port number of switch which this link departs from
      # @option h [Integer] :to_dpid Switch dpid which this link peer to
      # @option h [Integer] :to_portno port number of switch which this link peer to
      def initialize( h )
        raise ArgumentError, "Key element for Link missing in Hash" if h.values_at(:from_dpid, :from_portno, :to_dpid, :to_portno).include? nil

        @attributes = Hash.new
        @from_dpid = h[:from_dpid]
        @from_portno = h[:from_portno]
        @to_dpid = h[:to_dpid]
        @to_portno = h[:to_portno]
        update_attributes( h );
        @from_dpid.freeze
        @from_portno.freeze
        @to_dpid.freeze
        @to_portno.freeze
      end
      
      # @param [Hash] h Hash containing Link attributes. Elements listed in Options will be ignored.
      # @option (see #initialize)
      def update_attributes( h )
        h.each_pair do |k,v|
          next if k == :from_dpid or k == :from_portno
          next if k == :to_dpid or k == :to_portno
          @attributes[k] = v
        end
      end
      
      def to_s
        "Link (0x#{@from_dpid.to_s(16)}:#{@from_portno.to_s})->(0x#{@to_dpid.to_s(16)}:#{@to_portno.to_s}) - #{@attributes.inspect}"
      end
    end
    
    class Switch
      attr_reader :dpid
      # Hash of Ports: port_no -> Port
      # @note Manipulation of ports has no impact on topology. 
      #       e.g. Removing element from ports will NOT delete a links on that port.
      attr_reader :ports
      # Hash of inbound,outbound Link
      # @note Do not directly add/remove elements in this Hash. 
      #       These hash will be updated through ToplogyCache methods.
      attr_reader :links_in, :links_out
      attr_reader :attributes
      
      # @param [Hash] sw Hash containing Switch properties. Elements not listed in Options will be added to @attributes 
      # @option sw [Integer] :dpid Switch dpid
      def initialize( sw )
        raise ArgumentError, "Key element for Switch missing in Hash" unless sw.include? :dpid

        @attributes = Hash.new
        @dpid = sw[:dpid]
        update_attributes( sw )
        @dpid.freeze
        @ports = Hash.new
        @links_in = Hash.new
        @links_out = Hash.new
      end
      
      # @param [Port] port Port instance to add to switch
      def add_port port
        @ports[port.portno] = port;
      end
      
      # @param [Integer] portno Create a Port instance and add to switch
      def add_port_by_portno portno
        @ports[portno] = Port.new( { :dpid => @dpid, :portno => portno} )
      end
      
      # @param [Port] port Port instance to delete from
      def del_port port
        @ports.delete( port.portno )
      end
      
      # @param [Integer] portno port number to delete
      def del_port_by_portno portno
        @ports.delete( portno );
      end
      
      # @param [Hash] h Hash containing Switch attributes. Elements listed in Options will be ignored.
      # @option (see #initialize)
      def update_attributes( h )
        h.each_pair do |k,v|
          next if k == :dpid
          @attributes[k] = v
        end
      end
      
      # (see Port#initialize)
      def update_port_by_hash port
        raise ArgumentError, "Key element for Port missing in Hash" unless port.include? :portno

        if port[:up] then
          portno = port[:portno]
          add_port_by_portno portno if not @ports.include? portno
          @ports[portno].update_attributes port
        else
          @ports.delete( port[:portno] )
        end
      end
      
      def to_s
        s = "Switch 0x#{@dpid.to_s(16)} - #{@attributes.inspect}\n"
        @ports.each_pair do |k,v|
          s += " #{v.to_s}\n"
        end
        s += " Links_in\n"
        @links_in.each_pair do |k,v|
          s += "  <=0x#{k[FROM_DPID].to_s(16)}:#{k[FROM_PORTNO]}\n"
        end
        s += " Links_out\n"
        @links_out.each_pair do |k,v|
          s += "  =>0x#{k[TO_DPID].to_s(16)}:#{k[TO_PORTNO]}\n"
        end
        return s
      end
    end
    
    # Topology Cache structure
    class Cache
      # Hash of Switches: dpid -> Switch
      # @note Do not directly add/remove elements in this Hash. 
      attr_reader :switches
      # Hash of Links: [from.dpid, from.port_no, to.dpid, to.port_no] -> Links
      # @note Do not directly add/remove elements in this Hash. 
      attr_reader :links
      
      def initialize
        @switches = Hash.new
        @links = Hash.new;
      end
      
      # Add a switch to topology cache.
      def add_switch sw
        @switches[ sw.dpid ] = sw;
      end
      
      # Delete a switch from Topology cache.
      # @note Links from/to the switch will also be removed 
      def del_switch sw
        del_switch_by_dpid sw.dpid
      end
      
      # Delete a switch from Topology cache using dpid
      # @see #del_switch
      def del_switch_by_dpid dpid
        remove_links = @links.select { |k,v| (k[FROM_DPID] == dpid || k[TO_DPID] == dpid) }
        remove_links.each { |l| self.del_link_by_key_tuple( l[0] ) }
        @switches.delete dpid
      end
      
      def lookup_switch_by_dpid dpid
        @switches[dpid]
      end
      
      # Add a link to Topology cache.
      # @note Corresponding Switch object's links_out, links_in will also be updated.
      def add_link link
        key = [link.from_dpid, link.from_portno, link.to_dpid, link.to_portno ];
        key.each { |e| e.freeze }
        key.freeze
        
        sw_from = @switches[ link.from_dpid ]
        sw_from = add_switch( link.from_dpid ) unless sw_from
        sw_to = @switches[ link.to_dpid ]
        sw_to = add_switch( link.to_dpid ) unless sw_to
        
        sw_from.links_out[ key ] = link
        sw_to.links_in[ key ] = link
        @links[ key ] = link
      end
      
      # Delete a link from Topology cache.
      # @note Corresponding Switch object's links_out, links_in will also be updated.
      def del_link link
        del_link_by_key_tuple [link.from_dpid, link.from_portno, link.to_dpid, link.to_portno ]
      end
      
      def del_link_by_key_elements from_dpid, from_portno, to_dpid, to_portno
        del_link_by_key_tuple [from_dpid, from_portno, to_dpid, to_portno ]
      end 
      
      # Delete a link from Topology cache.
      # @param [Array<Integer,Integer,Integer,Integer>] key
      #   4 element array. [from.dpid, from.port_no, to.dpid, to.port_no]
      def del_link_by_key_tuple key
        sw_from = @switches[ key[FROM_DPID] ];
        sw_to = @switches[ key[TO_DPID] ];
        
        sw_from.links_out.delete( key ) if sw_from
        sw_to.links_in.delete( key ) if sw_to
        @links.delete( key );
      end
      
      # @param [Hash] h look up a link instance using key elements listed in Options
      # @option (see Link#initialize)
      def lookup_link_by_hash h
        key = [ h[:from_dpid], h[:from_port], h[:to_dpid], h[:to_portno] ];
        @links[ key ];
      end

      # Update Switch instance. Switch instance will be created if it does not exist.
      # Switch instance will be removed if the state is not up 
      # @param [Hash] sw switch instance info hash 
      # @option (see Switch#initialize)
      def update_switch_by_hash sw
        raise ArgumentError, "Key element for Switch missing in Hash" unless sw.include? :dpid
        
        if sw[:up] then
          s = lookup_switch_by_dpid( sw[:dpid] )
          if s != nil then
            s.update_attributes( sw )
          else
            add_switch Topology::Switch.new( sw )
          end
        else
          del_switch_by_dpid sw[:dpid]
        end
      end
      
      # Update Link instance. Link instance will be created if it does not exist.
      # Link instance will be removed if the state is not up 
      # @param [Hash] link link instance info hash 
      # @option (see Link#initialize)
      def update_link_by_hash link
        raise ArgumentError, "Key element for Link missing in Hash" if link.values_at(:from_dpid, :from_portno, :to_dpid, :to_portno).include? nil
        
        if link[:up] then
          l = lookup_link_by_hash( link )
          if l != nil then
            # link exist => update attributes
            l.update_attributes( link )
          else
            add_link Topology::Link.new( link )
          end
        else
          del_link_by_key_elements(link[:from_dpid],link[:from_portno],link[:to_dpid],link[:to_portno])
        end
      end
      
      # Update Port instance. Port instance will be created if it does not exist.
      # Port instance will be removed if the state is not up 
      # @param [Hash] port port instance info hash 
      # @option (see Port#initialize)
      def update_port_by_hash port
        raise ArgumentError, "Key element for Port missing in Hash" if port.values_at(:dpid, :portno).include? nil
        
        if port[:up] then
          s = lookup_switch_by_dpid( port[:dpid] )
          if s == nil then
            s = add_switch Topology::Switch.new( {:dpid => port[:dpid]} )
          end
          s.update_port_by_hash( port )
        else
          s = lookup_switch_by_dpid( port[:dpid] )
          if s != nil then
            s.update_port_by_hash( port )
          end
        end
      end
      
      def to_s
        s = "[Topology Cache]\n"
        @switches.each_pair { |k,v|
          s += v.to_s
        }
        @links.each_pair do |k,v|
          s += "#{v.to_s}\n"
        end
        return s
      end
      
    end
    
  end
  
  # module to add cached topology information capability to Controller
  #
  # @example
  #  class HelloSwitch < Controller
  #    include TopologyCache
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
  #      rebuild_cache
  #    end
  #    
  #    def cache_ready cache
  #      info "Topology Cache ready!"
  #      p cache
  #
  #      # You can do whatever with cache after this point.
  #      # Topology::Cache instance can be obtained later using #get_cache method.
  #    end
  #    
  #    def link_status_updated link
  #      info "link_status_updated!"
  #      p link
  #      
  #      # Do what ever before Topology Cache update
  #      # Note: Link instance will be removed after cache update, if the state
  #      #       was not up.
  #      
  #      # (Optional) Manually update Cache
  #      # Note: Cache will be automatically updated after exit from this handler
  #      #       even if this manual update 
  #      update_cache_by_switch_hash sw
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
  module TopologyCache
    include Topology
    
    #
    # @private Just a placeholder for YARD.
    #
    def self.handler name
      # Do nothing.
    end
    
    # returns a reference to current cache
    def get_cache
      @cache
    end
    
    def cache_ready?
      @all_link and @all_switch and @all_port
    end
    
    #
    # @!method cache_ready( cache )
    #
    # @abstract cache_ready event handler. Override this to implement a custom handler.
    #
    # @param [Cache] cache
    #   Reference to current topology cache. 
    handler :cache_ready
    
    # 
    # Rebuilds topology cache.
    # cache_ready will be called on cache rebuild complete
    # @note  send_all_\\{switch,link,port\\}_status_request will be called 
    #  internally thus all_\\{switch,link,port\\}_status_reply 
    #  event call back will be executed as a side-effect of this function call.
    def rebuild_cache
      @need_cache_ready_notify = true
      @cache_up_to_date = false
      @cache = Topology::Cache.new
      @all_link = false
      @all_switch = false
      @all_port = false
      
      send_all_switch_status_request
      send_all_link_status_request
      send_all_port_status_request
    end
    
    def cache_up_to_date?
      cache_ready? and @cache_up_to_date
    end
    
    # call inside switch_status_updated handler to update cache to latest state
    # @note cache will be automatically updated after handler exit if this method was not called.
    def update_cache_by_switch_hash sw
      _switch_status_updated sw
    end

    # call inside link_status_updated handler to update cache to latest state
    # @note cache will be automatically updated after handler exit if this method was not called.
    def update_cache_by_link_hash link
      _link_status_updated link
    end

    # call inside port_status_updated handler to update cache to latest state
    # @note cache will be automatically updated after handler exit if this method was not called.
    def update_cache_by_port_hash port
      _port_status_updated port
    end
    
    ######################
    protected
    ######################
    def _switch_status_updated sw
      @cache = Topology::Cache.new unless @cache
      @cache.update_switch_by_hash( sw )
      @cache_up_to_date = true
    end

    def _port_status_updated port
      @cache = Topology::Cache.new unless @cache
      @cache.update_port_by_hash( port )
      @cache_up_to_date = true
    end

    def _link_status_updated link
      @cache = Topology::Cache.new unless @cache
      @cache.update_link_by_hash( link )
      @cache_up_to_date = true
    end

    def _all_link_status_reply links
      links.each {|e| _link_status_updated(e) }
      @all_link = true
      notify_cache_ready if @need_cache_ready_notify and cache_ready? 
    end

    def _all_port_status_reply ports
      ports.each {|e| _port_status_updated(e) }
      @all_port = true
      notify_cache_ready if @need_cache_ready_notify and cache_ready? 
    end

    def _all_switch_status_reply switches
      switches.each {|e| _switch_status_updated(e) }
      @all_switch = true
      notify_cache_ready if @need_cache_ready_notify and cache_ready? 
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


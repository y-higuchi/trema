
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
      
      def initialize( *args )
        @attributes = Hash.new
        if args.length == 2 then
          @dpid = args[0];
          @portno = args[1];
        elsif args.length == 1 then
          raise ArgumentError, "Expected a Hash for argument. #{p args[0]}" unless args[0].is_a?(Hash)
          h = args[0]
          @dpid = h[:dpid]
          @portno = h[:portno]
          update_attributes( h )
        else
          raise ArgumentError, "Wrong number of arguments. #{p args}"
        end
        @dpid.freeze
        @portno.freeze 
      end

      def update_attributes( hash )
        hash.each_pair do |k,v|
          next if k == :dpid or k == :portno
          @attributes[k] = v
        end
      end
    end
    
    class Link
      attr_reader :from_dpid, :from_portno, :to_dpid, :to_portno
      attr_reader :attributes
      
      def initialize( *args )
        @attributes = Hash.new
        if args.length == 4 then
          @from_dpid = args[FROM_DPID];
          @from_portno = args[FROM_PORTNO];
          @to_dpid = args[TO_DPID];
          @to_portno = args[TO_PORTNO];
        elsif args.length == 1 then
          raise ArgumentError, "Expected a Hash for argument. #{p args[0]}" unless args[0].is_a?(Hash)
          h = args[0]
          @from_dpid = h[:from_dpid]
          @from_portno = h[:from_portno]
          @to_dpid = h[:to_dpid]
          @to_portno = h[:to_portno]
          update_attributes( h );
        else
          raise ArgumentError, "Wrong number of arguments. #{p args}"
        end
        @from_dpid.freeze
        @from_portno.freeze
        @to_dpid.freeze
        @to_portno.freeze
      end
      
      def update_attributes( hash )
        hash.each_pair do |k,v|
          next if k == :from_dpid or k == :from_portno
          next if k == :to_dpid or k == :to_portno
          @attributes[k] = v
        end
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
      
      def initialize( sw )
        @attributes = Hash.new
        if sw.is_a? Integer then
          @dpid = sw
        elsif sw.is_a? Hash then
          @dpid = sw[:dpid]
          update_attributes( sw )
        else
          raise ArgumentError, "Expected a Hash or Integer for argument. #{p sw}"
        end
        @dpid.freeze
        @ports = Hash.new
        @links_in = Hash.new
        @links_out = Hash.new
      end
      
      def add_port port
        @ports[port.portno] = port;
      end
      
      def add_port_by_portno portno
        @ports[portno] = Port.new portno;
      end
      
      def del_port port
        @ports.delete( port.portno )
      end
      
      def del_port_by_portno portno
        @ports.delete( portno );
      end
      
      def update_attributes( hash )
        hash.each_pair do |k,v|
          next if k == :dpid
          @attributes[k] = v
        end
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
      # @param [Array] key
      #   4 element array. [from.dpid, from.port_no, to.dpid, to.port_no]
      def del_link_by_key_tuple key
        sw_from = @switches[ key[FROM_DPID] ];
        sw_to = @switches[ key[TO_DPID] ];
        
        sw_from.links_out.delete( key ) if sw_from
        sw_to.links_in.delete( key ) if sw_to
        @links.delete( key );
      end
      
      def lookup_link_by_hash hash
        key = [ hash[:from_dpid], hash[:from_port], hash[:to_dpid], hash[:to_protno] ];
        @links[ key ];
      end
    end
    
  end
  
  # module to add cached topology information capability to Controller
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
      @all_link and @all_switch
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
    # @note  send_all_\{switch,link,port\}_status_request will be invoked internally thus 
    #        all_\{switch,link,port\}_status_reply event call back will be executed.
    def rebuild_cache
      @need_cache_ready_notify = true
      @cache = Topology::Cache.new
      @all_link = false
      @all_switch = false
      
      send_all_switch_status_request
      send_all_link_status_request
      send_all_port_status_request
    end
    
    ######################
    protected
    ######################
    def _switch_status_updated sw
      @cache = Topology::Cache.new unless @cache
      
      if sw[:up] then
        s = @cache.lookup_switch_by_dpid( sw[:dpid] )
        if s != nil then
          s.update_attributes( sw )
        else
          @cache.add_switch Topology::Switch.new( sw )
        end
      else
        @cache.del_switch_by_dpid sw[:dpid]
      end
    end
    
    def _port_status_updated port
      @cache = Topology::Cache.new unless @cache
      s = @cache.lookup_switch_by_dpid( port[:dpid] )
      if s == nil then
        s = @cache.add_switch Topology::Switch.new( port[:dpid] )
      end
      
      # TODO implement add port
    end
    
    def _link_status_updated link
      @cache = Topology::Cache.new unless @cache
      
      if link[:up] then
        l = @cache.lookup_link_by_hash( link )
        if l != nil then
          # link exist => update attributes
          l.update_attributes( link )
        else
          @cache.add_link Topology::Link.new( link )
        end
      else
        @cache.del_link_by_key_elements(link[:from_dpid],link[:from_portno],link[:to_dpid],link[:to_portno])
      end  
    end
    
    def _all_link_status_reply links
      links.each {|e| _link_status_updated(e) }
      @all_link = true
      notify_cache_ready if @need_cache_ready_notify and cache_ready? 
    end
    
    def _all_port_status_reply ports
      ports.each {|e| _port_status_updated(e) }
    end
    
    def _all_switch_status_reply switches
      switches.each {|e| _switch_status_updated(e) }
      @all_switch = true
      notify_cache_ready if @need_cache_ready_notify and cache_ready? 
    end
    
    def notify_cache_ready
      if self.respond_to? :cache_ready then
        cache_ready @cache
      end
      @need_cache_ready_notify = false
    end

  end
end


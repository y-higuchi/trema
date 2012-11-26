
module Trema::Topology
  
  class SwitchNotFound < Exception
  end
  
  # Link Hash key 4-tuple's array index
  FROM_DPID = 0
  FROM_PORTNO = 1
  TO_DPID = 2
  TO_PORTNO = 3
  
  class Port
    attr_reader :dpid, :portno
    attr_reader :attributes
    
    def initialize( dpid, portno )
      @dpid = dpid.freeze
      @portno = portno.freeze 
      @attributes = Hash.new
    end
  end
  
  class Link
    attr_reader :from_dpid, :from_portno, :to_dpid, :to_portno
    attr_reader :attributes
    
    def initialize( from_dpid, from_portno, to_dpid, to_portno )
      @from_dpid = from_dpid;
      @from_portno = from_portno;
      @to_dpid = to_dpid;
      @to_portno = to_portno;
      @attributes = Hash.new
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
    
    def initialize( dpid )
      @dpid = dpid.freeze
      @ports = Hash.new
      @links_in = Hash.new
      @links_out = Hash.new
      @attributes = Hash.new
    end
    
    def addPort port
      @ports[port.portno] = port;
    end
    
    def addPortByPortno portno
      @ports[portno] = Port.new portno;
    end
    
    def delPort port
      @ports.delete( port.portno )
    end
    
    def delPortByPortno portno
      @ports.delete( portno );
    end
  end
  
  # Topology Cache structure
  class TopologyCache
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
    def addSwitch sw
      @switches[ sw.dpid ] = sw;
    end
    
    # Delete a switch from Topology cache.
    # @note Links from/to the switch will also be removed 
    def delSwitch sw
      delSwitchByDPID sw.dpid
    end
    
    # Delete a switch from Topology cache using dpid
    # @see #delSwitch
    def delSwitchByDPID dpid
      remove_links = @links.select { |k,v| (k[FROM_DPID] == dpid || k[TO_DPID] == dpid) }
      remove_links.each { |l| self.delLinkByKey( l[0] ) }
      @switches.delete dpid
    end
    
    # Add a link to Topology cache.
    # @note Corresponding Switch object's links_out, links_in will also be updated.
    def addLink link
      key = [link.from_dpid, link.from_portno, link.to_dpid, link.to_portno ];
      key.each { |e| e.freeze }
      key.freeze
      
      sw_from = @switches[ link.from_dpid ];
      raise SwitchNotFound, "Swich with dpid 0x#{link.from_dpid.to_s(16)} not found" unless sw_from
      sw_to = @switches[ link.to_dpid ];
      raise SwitchNotFound, "Swich with dpid 0x#{link.to_dpid.to_s(16)} not found" unless sw_to
      
      sw_from.links_out[ key ] = link;
      sw_to.links_in[ key ] = link;
      @links[ key ] = link;
    end
    
    # Delete a link from Topology cache.
    # @note Corresponding Switch object's links_out, links_in will also be updated.
    def delLink link
      delLinkByKey [link.from_dpid, link.from_portno, link.to_dpid, link.to_portno ]
    end
    
    def delLinkByKeyElm from_dpid, from_portno, to_dpid, to_portno
      delLinkByKey [from_dpid, from_portno, to_dpid, to_portno ]
    end 
    
    # Delete a link from Topology cache.
    # @param [Array] key
    #   4 element array. [from.dpid, from.port_no, to.dpid, to.port_no]
    def delLinkByKey key
      sw_from = @switches[ key[FROM_DPID] ];
      sw_to = @switches[ key[TO_DPID] ];
      
      sw_from.links_out.delete( key );
      sw_to.links_in.delete( key );
      @links.delete( key );
    end
    
    # enumerator for all port  etc.
  end
end


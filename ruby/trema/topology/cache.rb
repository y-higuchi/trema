module Trema
  module Topology
    # Topology Cache structure
    class Cache
      # Hash of Switches: dpid => Switch
      # @note Do not directly add/remove elements in this Hash. 
      attr_reader :switches
      # Hash of Links: [from.dpid, from.port_no, to.dpid, to.port_no] => Links
      # @note Do not directly add/remove elements in this Hash. 
      attr_reader :links
      
      # Create empty Cache
      def initialize
        @switches = Hash.new
        @links = Hash.new;
      end
      
      # @group Switch manipulation methods
      
      # Add a switch to topology cache.
      def add_switch sw
        raise TypeError, "Trema::Topology::Switch expected" if not sw.is_a?(Switch)
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
      
      # @group Link manipulation methods
      
      # Add a link to Topology cache.
      # @note Corresponding Switch object's links_out, links_in will also be updated.
      def add_link link
        key = link.key
        key.each { |e| e.freeze }
        key.freeze
        
        sw_from = @switches[ link.from_dpid ]
        sw_from = add_switch Switch[ { :dpid => link.from_dpid } ]  if sw_from == nil
        sw_to = @switches[ link.to_dpid ]
        sw_to = add_switch Switch[ { :dpid => link.to_dpid } ] if sw_to == nil
        
        sw_from.add_outbound_link link
        sw_to.add_inbound_link link
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
      # @param [Array(Integer,Integer,Integer,Integer)] key
      #   4 element array. [from.dpid, from.port_no, to.dpid, to.port_no]
      def del_link_by_key_tuple key
        sw_from = @switches[ key[FROM_DPID] ];
        sw_to = @switches[ key[TO_DPID] ];
        
        sw_from.del_link_by_key( key ) if sw_from
        sw_to.del_link_by_key( key ) if sw_to
        @links.delete( key )
      end
      
      # @param [Hash] link look up a link instance using key elements listed in Options
      # @option (see Link.[])
      def lookup_link_by_hash link
        key = [ link[:from_dpid], link[:from_portno], link[:to_dpid], link[:to_portno] ];
        return @links[ key ]
      end

      # @group Update by Hash methods
      
      # Update Switch instance. Switch instance will be created if it does not exist.
      # Switch instance will be removed if the state is not up 
      # @param [Hash] sw switch instance info hash 
      # @option (see Switch.[])
      def update_switch_by_hash sw
        raise ArgumentError, "Key element for Switch missing in Hash" unless sw.include? :dpid
        
        if sw[:up] then
          s = lookup_switch_by_dpid( sw[:dpid] )
          if s != nil then
            s.update( sw )
          else
            add_switch Switch[ sw ]
          end
        else
          del_switch_by_dpid sw[:dpid]
        end
      end
      
      # Update Link instance. Link instance will be created if it does not exist.
      # Link instance will be removed if the state is not up 
      # @param [Hash] link link instance info hash 
      # @option (see Link.[])
      def update_link_by_hash link
        raise ArgumentError, "Key element for Link missing in Hash" if link.values_at(:from_dpid, :from_portno, :to_dpid, :to_portno).include? nil
        
        if link[:up] then
          l = lookup_link_by_hash( link )
          if l != nil then
            # link exist => update attributes
            l.update( link )
          else
            add_link Link[ link ]
          end
        else
          del_link_by_key_elements(link[:from_dpid],link[:from_portno],link[:to_dpid],link[:to_portno])
        end
      end
      
      # Update Port instance. Port instance will be created if it does not exist.
      # Port instance will be removed if the state is not up 
      # @param [Hash] port port instance info hash 
      # @option (see Port.[])
      def update_port_by_hash port
        raise ArgumentError, "Key element for Port missing in Hash" if port.values_at(:dpid, :portno).include? nil
        
        if port[:up] then
          s = lookup_switch_by_dpid( port[:dpid] )
          if s == nil then
            s = add_switch Switch[ {:dpid => port[:dpid]} ]
          end
          s.update_port_by_hash( port )
        else
          s = lookup_switch_by_dpid( port[:dpid] )
          if s != nil then
            s.update_port_by_hash( port )
          end
        end
      end
      
      # @endgroup
      
      def to_s
        s = "[Topology Cache]\n"
        s << "(Empty)\n" if @switches.empty? and @links.empty?
        @switches.each_pair { |k,v|
          s << v.to_s
        }
        @links.each_pair do |k,v|
          s << "#{v.to_s}\n"
        end
        return s
      end
    end
  end
end

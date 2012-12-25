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


module Trema
  module Topology
    class Switch < Hash
      # Hash of Ports: port_no => Port
      # @note Manipulation of ports has no impact on topology. 
      #       e.g. Removing element from ports will NOT delete a links on that port.
      attr_reader :ports
      # Hash of inbound,outbound Link: [from.dpid, from.port_no, to.dpid, to.port_no] => Links
      # @note Do not directly add/remove elements in this Hash. 
      #       These hash will be updated through ToplogyCache methods.
      attr_reader :links_in, :links_out
      
      def dpid
        return self[:dpid]
      end
      
      # @return [Integer] Switch key 4-tuple for this Switch instance
      def key
        return dpid
      end
      
      # @return [String] Switch key as a String
      def key_str
        return "S#{ dpid.to_s(16) }"
      end
      
      # Switch constructor.
      # @param [Hash] sw Hash containing Switch properties. Must at least contain keys listed in Options. 
      # @option sw [Integer] :dpid Switch dpid
      # @return Switch
      # @example
      #  sw = Switch[ {:dpid => 0x1234} ]
      def Switch.[]( sw )
        raise ArgumentError, "Key element for Switch missing in Hash" unless sw.include? :dpid

        sw[:dpid].freeze
        s = super( sw )
        s.initialize_members
        return s
      end
      
      # @param k Hash key element
      # @return [Boolean] true if k is key element for Switch
      def Switch.is_key?( k )
        return ( k == :dpid )
      end
      
      # @private
      def initialize( *arg )
        raise ArgumentError, "Empty Switch cannot be created. Use Switch[ {...} ] form."
      end
      
      def initialize_members
        @ports = Hash.new
        @links_in = Hash.new
        @links_out = Hash.new
        return self
      end
      
      # @param [Port] port Port instance to add to switch
      def add_port port
        raise TypeError, "Trema::Topology::Port expected" if not port.is_a?(Port)
        raise ArgumentError, "dpid mismatch. 0x#{ self.dpid.to_s(16) } expected but received: 0x#{ port.dpid.to_s(16) }" if (self.dpid != port.dpid)
        @ports[port.portno] = port;
      end
      
      # @param [Integer] portno Create a Port instance and add to switch
      def add_port_by_portno portno
        @ports[portno] = Port[ { :dpid => self.dpid, :portno => portno} ]
      end
      
      # @param [Port] port Port instance to delete from
      def del_port port
        @ports.delete( port.portno )
      end
      
      # @param [Integer] portno port number to delete
      def del_port_by_portno portno
        @ports.delete( portno );
      end
      
      # Update port on this switch by Hash
      # @param [Hash] port Hash containing info about updated port.
      # @see Port.[]
      def update_port_by_hash port
        p = Port[ port ]

        if p[:up] then
          portno = p[:portno]
          if @ports.include?( portno ) then
            @ports[portno].update p
          else
            add_port p
          end
        else
          @ports.delete( port[:portno] )
        end
      end
      
      # @param [Link] link inbound link to add.
      def add_inbound_link link
        raise ArgumentError, "Specified link is not a link to this switch" if link.to_dpid != self.dpid
        @links_in[ link.key ] = link
      end
      
      # @param [Link] link outbound link to add.
      def add_outbound_link  link
        raise ArgumentError, "Specified link is not a link from this switch" if link.from_dpid != self.dpid
        @links_out[ link.key ] = link
      end
      
      # @param [Link] link inbound link to delete.
      def del_inbound_link link
        @links_in.delete link.key
      end
      
      # @param [Link] link outbound link to delete
      def del_outbound_link link
        @links_out.delete link.key
      end
      
      # @param [Array(Integer, Integer, Integer, Integer)] Link key 4-tuple of the link to delete
      def del_link_by_key key
        @links_in.delete key
        @links_out.delete key
      end
      
      def to_s
        s = "Switch 0x#{ dpid.to_s(16) } - #{ self.select {|k,v| !Switch.is_key?(k) }.inspect }\n"
        @ports.each_pair do |k,v|
          s << " #{v.to_s}\n"
        end
        s << " Links_in\n" if not @links_in.empty?
        @links_in.each_pair do |k,v|
          s << "  <= 0x#{ k[FROM_DPID].to_s(16) }:#{ k[FROM_PORTNO] }\n"
        end
        s << " Links_out\n" if not @links_out.empty?
        @links_out.each_pair do |k,v|
          s << "  => 0x#{ k[ TO_DPID ].to_s(16) }:#{ k[ TO_PORTNO ] }\n"
        end
        return s
      end
    end
  end
end

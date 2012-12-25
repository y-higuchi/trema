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
    class Port < Hash
      
      # @return [Integer] datapath ID of the switch which this port belong to.
      def dpid
        return self[:dpid]
      end
      
      # @return [Integer] port number
      def portno
        return self[:portno]
      end
      
      # @return [Array(Integer,Integer)] Port key 2-tuple for this Port instance
      def key
        return [dpid, portno]
      end
      
      # @return [String] Port key as a String
      def key_str
        return "P#{ dpid.to_s(16) }-#{ portno.to_s }"
      end
      
      # Port constructor
      # @param [Hash] port Hash containing Port properties. Must at least contain keys listed in Options.
      # @option port [Integer] :dpid Switch dpid which this port belongs
      # @option port [Integer] :portno port number
      # @return [Port]
      # @example
      #   port = Port[ {:dpid => 1234, :portno => 42} ]
      def Port.[]( port ) 
        raise ArgumentError, "Key element for Port missing in Hash" if port.values_at(:dpid, :portno).include? nil
        
        port[ :dpid ].freeze
        port[ :portno ].freeze
        super( port )
      end

      # @param k Hash key element
      # @return [Boolean] true if k is key element for Port
      def Port.is_key?( k )
        return (k == :dpid or k == :portno)
      end
      
      # @private
      def initialize( *arg )
        raise ArgumentError, "Empty Port cannot be created. Use Port[ {...} ] form."
      end

      def to_s
        "Port 0x#{ dpid.to_s(16) }:#{ portno.to_s } - #{ self.select {|k,v| !Port.is_key?(k) }.inspect }"
      end
    end
  end
end

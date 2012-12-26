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
    # A class to represent a link in a Topology 
    class Link < Hash
      
      # @return [Integer] datapath ID of the switch which this link departs from
      def from_dpid
        return self[:from_dpid]
      end
      
      # @return [Integer] port number which this link departs from
      def from_portno
        return self[:from_portno]
      end
      
      # @return [Integer] datapath ID of the switch which this link arrive to
      def to_dpid
        return self[:to_dpid]
      end
      
      # @return [Integer] port number which this link departs arrive to
      def to_portno
        return self[:to_portno]
      end
        
      # @return [Array(Integer,Integer,Integer,Integer)] Link key 4-tuple for this Link instance
      def key
        return [ from_dpid, from_portno, to_dpid, to_portno ]
      end
      
      # @return [String] Link key as a String
      def key_str
        return "L#{ from_dpid.to_s(16) }-#{ from_portno.to_s }-#{ to_dpid.to_s(16) }-#{ to_portno.to_s }"
      end
      
      # Link constructor.
      # @param [Hash] link Hash containing Link properties. Must at least contain keys listed in Options.
      # @option link [Integer] :from_dpid Switch dpid which this link departs from
      # @option link [Integer] :from_portno port number of switch which this link departs from
      # @option link [Integer] :to_dpid Switch dpid which this link peer to
      # @option link [Integer] :to_portno port number of switch which this link peer to
      # @return [Link]
      # @example
      #   link = Link[ {:from_dpid => 0x1234, :from_portno => 42, :to_dpid => 0x5678, :to_portno => 72 } ]
      def Link.[]( link )
        raise ArgumentError, "Key element for Link missing in Hash" if not Link.has_keys?(link)

        link[:from_dpid].freeze
        link[:from_portno].freeze
        link[:to_dpid].freeze
        link[:to_portno].freeze
        super( link )
      end
      
      # @param k Hash key element
      # @return [Boolean] true if k is key element for Link
      def Link.is_key?( k )
        return (k == :from_dpid or k == :from_portno or k == :to_dpid or k == :to_portno)
      end
      
      # Test if Hash has required key as a Link instance
      # @param hash Hash to test 
      # @return [Boolean] true if hash has all required keys.
      def Link.has_keys?( hash )
        return !(hash.values_at(:from_dpid, :from_portno, :to_dpid, :to_portno).include? nil)
      end
      
      # @private
      def initialize( *arg )
        raise ArgumentError, "Empty Link cannot be created. Use Link[ {...} ] form."
      end
      
      def to_s
        "Link (0x#{ from_dpid.to_s(16) }:#{ from_portno.to_s })->(0x#{ to_dpid.to_s(16) }:#{ to_portno.to_s }) - #{ self.select {|k,v| !Link.is_key?(k) }.inspect }"
      end
    end
  end
end

module Trema
  module Topology
    class Link < Hash
      
      def from_dpid
        return self[:from_dpid]
      end
      
      def from_portno
        return self[:from_portno]
      end
      
      def to_dpid
        return self[:to_dpid]
      end
      
      def to_portno
        return self[:to_portno]
      end
        
      # @return [Array(Integer,Integer,Integer,Integer)] Link key 4-tuple for this Link instance
      def key
        return [ from_dpid, from_portno, to_dpid, to_portno ]
      end
      
      # @return [String] Link key as a String
      def key_str
        return "#{ from_dpid.to_s(16) }-#{ from_portno.to_s }-#{ to_dpid.to_s(16) }-#{ to_portno.to_s }"
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
        raise ArgumentError, "Key element for Link missing in Hash" if link.values_at(:from_dpid, :from_portno, :to_dpid, :to_portno).include? nil

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
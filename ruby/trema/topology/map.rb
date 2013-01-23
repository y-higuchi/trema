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


module Trema
  module Topology
    # Topology Map structure
    class Map
      # @return [{Integer=>Switch}]  Hash of Switches: dpid => Switch
      # @note Do not directly add/remove elements in this Hash.
      attr_reader :switches
      # @return [{[Integer,Integer,Integer,Integer]=>Link}] Hash of Links: [from.dpid, from.port_no, to.dpid, to.port_no] => Links
      # @note Do not directly add/remove elements in this Hash.
      attr_reader :links
      # Create empty Map
      def initialize
        @switches = Hash.new
        @links = Hash.new
      end

      # @!group Switch manipulation methods


      # Add a switch to topology map.
      # @return [Switch] Switch instance added.
      def add_switch sw
        raise TypeError, "Trema::Topology::Switch expected" if not sw.is_a?(Switch)
        @switches[ sw.dpid ] = sw
      end


      # Delete a switch from Topology map.
      # @note Links from/to the switch will also be removed
      # @param [Switch,Hash] sw Switch instance or a Hash with Switch info
      def del_switch sw
        del_switch_by_dpid sw[:dpid]
      end


      # Delete a switch from Topology map using dpid
      # @see #del_switch
      def del_switch_by_dpid dpid
        remove_links = @links.select { |key,_| (key[FROM_DPID] == dpid || key[TO_DPID] == dpid) }
        remove_links.each { |kv_pair| self.del_link( kv_pair.first ) }
        @switches.delete dpid
      end


      # Get a switch from Topology map using dpid.
      # Switch instance will be created if not found.
      # @param [Integer] dpid dpid of the switch to look for.
      # @return [Switch] Switch instance for specified dpid
      def get_switch_for_dpid dpid
        sw = lookup_switch_by_dpid dpid
        sw ||= add_switch Switch.new( { :dpid => dpid } )
        return sw
      end

      # @!group Link manipulation methods


      # Add a link to Topology map.
      # @note Corresponding Switch object's links_out, links_in will also be updated.
      def add_link link
        raise TypeError, "Trema::Topology::Link expected" if not link.is_a?(Link)

        key = link.key
        key.each { |each| each.freeze }
        key.freeze

        sw_from = get_switch_for_dpid link.from_dpid
        sw_to = get_switch_for_dpid  link.to_dpid

        sw_from.add_link link
        sw_to.add_link link
        @links[ key ] = link
      end


      # Delete a link from Topology map.
      # @note Corresponding Switch object's links_out, links_in will also be updated.
      # @param [Link,Hash] link Link instance or a Hash with link info.
      def del_link link
        del_link_by_key [ link[:from_dpid], link[:from_portno], link[:to_dpid], link[:to_portno] ]
      end


      # Delete a link from Topology map.
      # @param [Array(Integer,Integer,Integer,Integer)] key
      #   4 element array. [from.dpid, from.port_no, to.dpid, to.port_no]
      def del_link_by_key key
        sw_from = @switches[ key[FROM_DPID] ];
        sw_to = @switches[ key[TO_DPID] ];

        sw_from.delete_link( key ) if sw_from
        sw_to.delete_link( key ) if sw_to
        @links.delete( key )
      end

      #
      # @!group Lookup map contents
      #

      # Lookup a switch from Topology map using dpid
      # @param [Integer] dpid dpid of the switch to look for.
      # @return [Switch] Switch instance found, or nil if not found.
      def lookup_switch_by_dpid dpid
        @switches[dpid]
      end


      # Lookup a link from Topology map.
      # @param [Hash] link look up a link instance using key elements listed in Options
      # @option (see Link#initialize)
      # @return [Link] Link instance found, or nil if not found.
      def lookup_link_by_hash link
        key = [ link[:from_dpid], link[:from_portno], link[:to_dpid], link[:to_portno] ];
        return @links[ key ]
      end


      #
      # @!group Update by Hash methods
      #

      # Update Switch instance. Switch instance will be created if it does not exist.
      # Switch instance will be removed if the state is not up
      # @param [Switch,Hash] sw Switch instance or a Hash with switch info
      # @option (see Switch#initialize)
      def update_switch sw
        sw = sw.property if sw.is_a?(Switch)
        raise ArgumentError, "Mandatory key element for Switch missing in Hash" if not Switch.has_mandatory_keys?( sw )

        dpid = sw[:dpid]
        if sw[:up] then
          s = lookup_switch_by_dpid( dpid )
          if s != nil then
            s.update( sw )
          else
            add_switch Switch.new( sw )
          end
        else
          del_switch_by_dpid dpid
        end
      end


      # Update Link instance. Link instance will be created if it does not exist.
      # Link instance will be removed if the state is not up
      # @param [Link,Hash] link Link instance or a Hash with link info
      # @option (see Link#initialize)
      def update_link link
        link = link.property if link.is_a?(Link)
        raise ArgumentError, "Mandatory key element for Link missing in Hash" if not Link.has_mandatory_keys?( link )

        if link[:up] then
          l = lookup_link_by_hash( link )
          if l != nil then
            l.update( link )
          else
            add_link Link.new( link )
          end
        else
          del_link link
        end
      end


      # Update Port instance. Port instance will be created if it does not exist.
      # Port instance will be removed if the state is not up
      # @param [Port,Hash] port Port instance or a Hash with port info
      # @option (see Port#initialize)
      def update_port port
        port = port.property if port.is_a?(Port)
        raise ArgumentError, "Mandatory key element for Port missing in Hash" if not Port.has_mandatory_keys?( port )
        
        dpid = port[:dpid]
        s = lookup_switch_by_dpid( dpid )
        if port[:up] then
          s ||= add_switch Switch.new( { :dpid => dpid } )
        end
        s.update_port( port ) if s != nil
      end
      
      #
      # @!endgroup
      #
      
      # Dump map info as a String
      # @return [String] content of this map.
      def to_s
        s = "Map:\n"
        s << "(Empty)\n" if @switches.empty? and @links.empty?
        @switches.each_pair do |_, sw|
          s << sw.to_s
        end
        @links.each_pair do |_, link|
          s << "#{ link.to_s }\n"
        end
        return s
      end
      
    end
  end
end

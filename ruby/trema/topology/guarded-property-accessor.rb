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
    module GuardedPropertyAccesor
      
      # Accessor for the property value of this node
      def []( key )
        return @property[key]
      end


      # Overwrite a property value of this node
      # @raise [ArgumentError] if key was a mandatory key of a node
      def []=( key, value )
        raise ArgumentError, "Overwriting #{key} is not allowed" if self.class.is_mandatory_key?(key)
        return @property[key] = value
      end


      # Delete a property of this node.
      # mandatory key will be treated as if it didn't exist.
      def delete( key )
        if block_given? then
          yield key if not @property.has_key?(key) or self.class.is_mandatory_key?(key)
        end
        return nil if self.class.is_mandatory_key?(key)
        return deleted = @property.delete(key)
      end


      # Update properties of this node using specified Hash or node
      # mandatory keys will be ignored
      def update( other )
        other = other.properties if other.is_a?(self.class)
        other = other.to_hash if not other.is_a?(Hash)

        other.each_pair do |key,value|
          @property[key] = value if not self.class.is_mandatory_key?(key)
        end
      end
      alias :merge! :update
    end
  end
end
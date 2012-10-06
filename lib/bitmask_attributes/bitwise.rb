module BitmaskAttributes

  module Nodes
    class BitwiseAnd < Arel::Nodes::InfixOperation
      def initialize left, right
        super(:&, left, right)
      end
    end
  end

  module Bitwise
    def &(other)
      Nodes::BitwiseAnd.new(self, other)
    end
  end

end

Arel::Attributes::Attribute.send(:include, BitmaskAttributes::Bitwise)

require 'bitmask_attributes/value_proxy'

module BitmaskAttributes
  extend ActiveSupport::Concern

  module ClassMethods

    def bitmask(attribute, options={}, &extension)

      unless options[:as] && options[:as].kind_of?(Array)
        raise ArgumentError, "Must provide an Array :as option"
      end

      variable = "@#{attribute}"
      values = options[:as]

      stub = Squeel::Nodes::Stub.new attribute

      # Where condition for zero or nil.
      eq_zero = if options[:null].nil? || options[:null]
        (stub == 0) | (stub == nil)
      else
        stub == 0
      end

      # Conveniently check for zero values.
      is_zero = lambda {|value| value.blank? || value == options[:zero_value]}
      not_zero = lambda {|value| !is_zero.(value)}

      masks = HashWithIndifferentAccess.new.tap do |masks|
        values.each_with_index do |value, index|
          masks[value] = 0b1 << index
        end
      end


      # Default Value

      if default = options[:default]
        after_initialize do
          send("#{attribute}=", default) unless send("#{attribute}?")
        end
      end


      # Class Methods

      define_singleton_method "values_for_#{attribute}" do
        values
      end

      define_singleton_method "bitmask_for_#{attribute}" do |*values|
        values.inject(0) do |mask, value|
          bit = is_zero.(value) ? 0 : masks[value]
          raise ArgumentError, "Unsupported value for #{attribute}: #{value.inspect}" if bit.nil?
          mask | bit
        end
      end

      define_singleton_method "#{attribute}_for_bitmask" do |value|
        unless value.is_a?(Fixnum) && value.between?(0, 2 ** masks.size - 1)
          raise ArgumentError, "Unsupported value for #{attribute}: #{value.inspect}"
        end
        masks.inject([]) do |values, (name, bitmask)|
          values.tap{values << name.to_sym if value & bitmask > 0}
        end
      end


      # Instance Methods

      define_method attribute do
        instance_variable_set variable, instance_variable_get(variable) ||
          ValueProxy.new(self, attribute, &extension)
      end

      define_method "#{attribute}=" do |value|
        if value.is_a?(Fixnum)
          value = self.class.send("#{attribute}_for_bitmask", value)
        end
        send(attribute).replace Array.wrap(value).reject &is_zero
      end

      values.each do |value|
        define_method "#{attribute}_for_#{value}?" do
          send("#{attribute}?", value)
        end
      end

      define_method "#{attribute}?" do |*values|
        if values.blank?
          send(attribute).present?
        else
          values.all? do |value|
            if is_zero.(value)
              send(attribute).blank?
            else
              send(attribute).include?(value)
            end
          end
        end
      end


      # Scopes

      scope "with_#{attribute}", proc {|*values|
        if values.blank?
          where{stub > 0}
        else
          values.inject(scoped) do |scope, value|
            if is_zero.(value)
              scope.where(eq_zero)
            else
              scope.where{stub.op('&', masks[value]) > 0}
            end
          end
        end
      }

      scope "without_#{attribute}", proc {|*values|
        if values.blank?
          send("no_#{attribute}")
        else
          mask = send("bitmask_for_#{attribute}", *values)
          relation = where{(stub == nil) | (stub.op('&', mask) == 0)}
          values.any?(&is_zero) ? relation.where{stub > 0} : relation
        end
      }

      scope "with_exact_#{attribute}", proc {|*values|
        if values.blank?
          send("no_#{attribute}")
        else
          mask = send("bitmask_for_#{attribute}", *values)
          where{stub == mask if values.any?(&not_zero)}
          .where{eq_zero if values.any?(&is_zero)}
        end
      }

      scope "no_#{attribute}", proc { where(eq_zero) }

      scope "with_any_#{attribute}", proc {|*values|
        if values.blank?
          where{stub > 0}
        else
          mask = send("bitmask_for_#{attribute}", *values)
          where do
            condition = stub.op('&', mask) != 0
            values.any?(&is_zero) ? (condition | eq_zero) : condition
          end
        end
      }

      values.each do |value|
        scope "#{attribute}_for_#{value}", proc {
          where{stub.op('&', masks[value]) != 0}
        }
      end

    end

  end
end

ActiveRecord::Base.send :include, BitmaskAttributes

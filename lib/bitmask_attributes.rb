require 'bitmask_attributes/value_proxy'

module BitmaskAttributes
  extend ActiveSupport::Concern

  module ClassMethods

    def bitmask(attribute, options={}, &extension)

      unless options[:as].kind_of?(Array)
        raise ArgumentError, "Must provide an Array :as option"
      end

      column = arel_table[attribute]
      quoted = connection.quote_column_name(attribute)

      # Where condition for zero or nil.
      eq_zero = if options[:null].nil? || options[:null]
        "#{quoted} = 0 OR #{quoted} IS NULL"
      else
        "#{quoted} = 0"
      end

      # Conveniently check for zero values.
      is_zero = -> value { value.blank? || value == options[:zero_value] }
      not_zero = -> value { !is_zero.(value) }

      # Masks for each value.
      masks = HashWithIndifferentAccess.new
      options[:as].each.with_index do |value, index|
        masks[value] = 0b1 << index
      end

      # Default Value

      if default = options[:default]
        after_initialize do
          send("#{attribute}=", default) unless read_attribute(attribute)
        end
      end


      # Class Methods

      define_singleton_method "values_for_#{attribute}" do
        options[:as].dup
      end

      define_singleton_method "bitmask_for_#{attribute}" do |*values|
        values.inject(0) do |mask, value|
          bit = is_zero.(value) ? 0 : masks[value]
          raise ArgumentError, "Unsupported value for #{attribute}: #{value.inspect}" if bit.nil?
          mask | bit
        end
      end

      define_singleton_method "#{attribute}_for_bitmask" do |value|
        unless value.is_a?(Integer) && value.between?(0, 2 ** masks.size - 1)
          raise ArgumentError, "Unsupported value for #{attribute}: #{value.inspect}"
        end
        values = []
        masks.each{ |name, mask| values << name.to_sym if value & mask > 0 }
        values
      end

      define_singleton_method "with_#{attribute}" do |*values|
        return where(column.gt(0)) if values.blank?
        values.reduce(all) do |scope, value|
          next scope.where(eq_zero) if is_zero.(value)
          scope.where("#{quoted} & #{masks[value]} > 0")
        end
      end

      define_singleton_method "without_#{attribute}" do |*values|
        return send("no_#{attribute}") if values.blank?
        mask = send("bitmask_for_#{attribute}", *values)
        relation = where("#{quoted} IS NULL OR #{quoted} & #{mask} = 0")
        values.any?(&is_zero) ? relation.where(column.gt(0)) : relation
      end

      define_singleton_method "with_exact_#{attribute}" do |*values|
        return send("no_#{attribute}") if values.blank?
        mask = send("bitmask_for_#{attribute}", *values)
        where(values.any?(&not_zero) ? column.eq(mask) : nil)
        .where(values.any?(&is_zero) ? eq_zero : nil)
      end

      define_singleton_method("no_#{attribute}"){ where(eq_zero) }

      define_singleton_method "with_any_#{attribute}" do |*values|
        return where(column.gt(0)) if values.blank?
        mask = send("bitmask_for_#{attribute}", *values)
        condition = "#{quoted} & #{mask} != 0"
        condition += " OR #{eq_zero}" if values.any?(&is_zero)
        where(condition)
      end

      options[:as].each do |value|
        define_singleton_method "#{attribute}_for_#{value}" do
          where("#{quoted} & #{masks[value]} != 0")
        end
      end


      # Instance Methods

      define_method attribute do
        value = instance_variable_get("@#{attribute}")
        value ||= ValueProxy.new(self, attribute, &extension)
        instance_variable_set "@#{attribute}", value
      end

      define_method "#{attribute}=" do |value|
        value ||= default if default
        if value.is_a?(Integer)
          value = self.class.send("#{attribute}_for_bitmask", value)
        end
        send(attribute).replace Array.wrap(value).reject &is_zero
      end

      options[:as].each do |value|
        define_method "#{attribute}_for_#{value}?" do
          send("#{attribute}?", value)
        end
      end

      define_method "#{attribute}?" do |*values|
        return send(attribute).present? if values.blank?
        values.all? do |value|
          next send(attribute).blank? if is_zero.(value)
          send(attribute).include?(value)
        end
      end

    end

  end
end

ActiveRecord::Base.send :include, BitmaskAttributes

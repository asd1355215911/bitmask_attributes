module BitmaskAttributes
  class ValueProxy < Array

    def initialize(record, attribute, &extension)
      @record = record
      @attribute = attribute
      instance_eval(&extension) if extension
      super(extract_values)
    end

    alias_method :_replace, :replace

    %w(push << delete replace reject! select!).each do |method|
      define_method method do |*args|
        super(*args).tap{updated!}
      end
    end

    def to_i
      @record.class.send("bitmask_for_#{@attribute}", *self)
    end

    private

    def updated!
      @record.send(:write_attribute, @attribute, to_i)
      _replace(map(&:to_sym))
      uniq!
    rescue ArgumentError => e
      _replace(extract_values)
      raise e
    end

    def extract_values
      stored = [@record.send(:read_attribute, @attribute) || 0, 0].max
      @record.class.send("#{@attribute}_for_bitmask", stored)
    end

  end
end

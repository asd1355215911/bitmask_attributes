module BitmaskAttributes
  class ValueProxy < Array

    def initialize(record, attribute)
      @record = record
      @attribute = attribute
      super(extract_values)
    end

    alias_method :_replace, :replace

    %w(push << delete replace reject! select! map!).each do |method|
      define_method method do |*args|
        super(*args).tap{updated!}
      end
    end

    def to_i
      @record.class.send("bitmask_for_#{@attribute}", *self)
    end

    private

    def updated!
      _replace(map(&:to_sym).uniq)
      @record[@attribute] = to_i
    rescue ArgumentError => e
      _replace(extract_values)
      raise e
    end

    def extract_values
      stored = @record[@attribute] || 0
      @record.class.send("#{@attribute}_for_bitmask", stored)
    end

  end
end

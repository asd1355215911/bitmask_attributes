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
      @record[@attribute] = _replace(map(&:to_sym).uniq).to_i
    rescue ArgumentError => e
      _replace(extract_values)
      raise e
    end

    def extract_values
      @record.class.send("#{@attribute}_for_bitmask", @record[@attribute] || 0)
    end

  end
end

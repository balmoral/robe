class Object
  def deep_dup
    dup
  end
end

class Array
  def deep_dup
    map { |e| e.deep_dup}
  end
end

class Set
  def deep_dup
    map { |e| e.deep_dup}
  end
end

class Hash
  def deep_dup
    {}.tap do |d|
      each do |key, value|
        d[key] = value.deep_dup
      end
    end
  end
end


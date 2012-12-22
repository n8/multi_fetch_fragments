class Customer < Struct.new(:name, :id)
  def cache_key
    "#{name}"
  end
end

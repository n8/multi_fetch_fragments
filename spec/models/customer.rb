class Customer < Struct.new(:name, :id)
  def cache_key
    "#{id}:#{name}"
  end
end

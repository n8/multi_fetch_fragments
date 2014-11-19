module MultiFetchFragments
  extend ActiveSupport::Concern

  included do
    alias_method_chain :render_collection, :multi_fetch_cache
    alias_method_chain :retrieve_template_keys, :multi_fetch_cache
    alias_method_chain :collection_with_template, :multi_fetch_cache
    alias_method_chain :collection_without_template, :multi_fetch_cache
  end

  private

  def cache_safe_variable_counter
    ('cache_safe_' + @variable_counter.to_s).to_sym
  end

  def retrieve_template_keys_with_multi_fetch_cache
    keys = @locals.keys
    keys << @variable         if @object || @collection
    keys << @variable_counter if @collection
    keys << cache_safe_variable_counter if @collection
    keys
  end

  def collection_with_template_with_multi_fetch_cache
    view, locals, template = @view, @locals, @template
    as, counter = @variable, @variable_counter

    if layout = @options[:layout]
      layout = find_template(layout, @template_keys)
    end

    index = -1
    @collection.map do |object|
      locals[as]      = object
      locals[counter] = (index += 1)

      locals[cache_safe_variable_counter] = cache_safe_variable_counter_value(object) || locals[counter]

      content = template.render(view, locals)
      content = layout.render(view, locals) { content } if layout
      content
    end
  end

  def collection_without_template_with_multi_fetch_cache
    view, locals, collection_data = @view, @locals, @collection_data
    cache = {}
    keys  = @locals.keys

    index = -1
    @collection.map do |object|
      index += 1
      path, as, counter = collection_data[index]

      locals[as]      = object
      locals[counter] ||= index

      locals[cache_safe_variable_counter] = cache_safe_variable_counter_value(object) || locals[counter]

      template = (cache[path] ||= find_template(path, keys + [as, counter]))
      template.render(view, locals)
    end
  end

  def cache_safe_variable_counter_value(object)
    if collection_index_map = @collection_index_map
      collection_index_map[object]
    end
  end

  def render_collection_with_multi_fetch_cache

    return nil if @collection.blank?

    if @options.key?(:spacer_template)
      spacer = find_template(@options[:spacer_template], @locals.keys).render(@view, @locals)
    end

    results = []

    if cache_collection?

      additional_cache_options = @options[:cache_options] || @locals[:cache_options] || {}

      keys_to_collection_map = {}
      @collection_index_map = {}

      @collection.each_with_index do |item, index|
        key = @options[:cache].respond_to?(:call) ? @options[:cache].call(item, index) : item

        @collection_index_map[item] = index

        key_with_optional_digest = nil
        if defined?(@view.fragment_name_with_digest)
          key_with_optional_digest = @view.fragment_name_with_digest(key, @view.view_cache_dependencies)
        elsif defined?(@view.cache_fragment_name)
          key_with_optional_digest = @view.cache_fragment_name(key)
        else
          key_with_optional_digest = key
        end

        expanded_key = fragment_cache_key(key_with_optional_digest)

        keys_to_collection_map[expanded_key] = item
      end


      # cache.read_multi & cache.write interfaces may require mutable keys, ie. dalli 2.6.0
      mutable_keys = keys_to_collection_map.keys.collect { |key| key.dup }

      result_hash = Rails.cache.read_multi(*mutable_keys)

      # if we had a cached value, we don't need to render that object from the collection.
      # if it wasn't cached, we need to render those objects as before
      @collection = (keys_to_collection_map.keys - result_hash.keys).map do |key|
        keys_to_collection_map[key]
      end

      non_cached_results = []

      # sequentially render any non-cached objects remaining
      if @collection.any?
        non_cached_results = @template ? collection_with_template : collection_without_template
      end

      # sort the result according to the keys that were fed in, cache the non-cached results
      mutable_keys.each do |key|

        cached_value = result_hash[key]
        if cached_value
          results << cached_value
        else
          non_cached_result = non_cached_results.shift
          Rails.cache.write(key, non_cached_result, additional_cache_options)

          results << non_cached_result
        end
      end

    else
      results = @template ? collection_with_template : collection_without_template
    end

    results.join(spacer).html_safe
  end

  def cache_collection?
    cache_option = @options[:cache].presence || @locals[:cache].presence
    ActionController::Base.perform_caching && cache_option
  end

  # from Rails fragment_cache_key in ActionController::Caching::Fragments. Adding it here since it's tucked inside an instance method on the controller, and 
  # it's utility could be used in a view without a controller
  def fragment_cache_key(key)
    ActiveSupport::Cache.expand_cache_key(key.is_a?(Hash) ? url_for(key).split("://").last : key, :views)
  end

  class Railtie < Rails::Railtie
    initializer "multi_fetch_fragments.initialize" do |app|
      ActionView::PartialRenderer.class_eval do
        include MultiFetchFragments
      end
    end
  end
end

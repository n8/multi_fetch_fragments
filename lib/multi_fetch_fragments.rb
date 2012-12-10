module MultiFetchFragments
  extend ActiveSupport::Concern

  included do
    alias_method_chain :render_collection, :multi_fetch_cache
  end

  private
    def render_collection_with_multi_fetch_cache
      return nil if @collection.blank?

      if @options.key?(:spacer_template)
        spacer = find_template(@options[:spacer_template]).render(@view, @locals)
      end

      result = []

      if cache_configured? && @options[:cache].present?
        keys_to_collection_map = {}

        @collection.each do |item| 
          key = @options[:cache].is_a?(Proc) ? @options[:cache].call(item) : item
          expanded_key = ActiveSupport::Cache.expand_cache_key(key)
          keys_to_collection_map[expanded_key] = item 
        end

        collection_to_keys_map = keys_to_collection_map.invert

        result_hash = Rails.cache.read_multi(keys_to_collection_map.keys)

        # if we had a cached value, we don't need to render that object from the collection. 
        # if it wasn't cached, we need to render those objects as before
        result_hash.each do |key, value|
          if value.present?
            collections_object = keys_to_collection_map[key]
            @collection.delete(collections_object)

            result << value
          end
        end

        # sequentially render any non-cached objects remaining, and cache them
        if @collection.any?
          collections_objects = @collection.clone

          non_cached_results = @template ? collection_with_template : collection_without_template

          non_cached_results.each_with_index do |item, index| 
            collection_object  = collections_objects[index]
            key = collection_to_keys_map[collection_object]
            Rails.cache.write(key, item)
          end

          result += non_cached_results
        end

      else
        result = @template ? collection_with_template : collection_without_template
      end
      
      result.join(spacer).html_safe
    end

  class Railtie < Rails::Railtie
    initializer "etag_version_ids.initialize" do |app|
      ActionView::PartialRenderer.class_eval do
        include MultiFetchFragments
      end
    end
  end
end
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

      results = []

      if ActionController::Base.perform_caching && @options[:cache].present?

        additional_cache_options = @options.fetch(:cache_options, {})
        keys_to_collection_map = {}

        @collection.each do |item|
          key = @options[:cache].is_a?(Proc) ? @options[:cache].call(item) : item
          expanded_key = ActiveSupport::Cache.expand_cache_key(key)
          keys_to_collection_map[expanded_key] = item
        end

        # Keys from a hash are freezed and memcached may need to touch them
        result_hash = Rails.cache.read_multi(keys_to_collection_map.keys.map(&:dup))

        # if we had a cached value, we don't need to render that object from the collection. 
        # if it wasn't cached, we need to render those objects as before
        result_hash.each do |key, value|
          if value
            collection_item = keys_to_collection_map[key]
            @collection.delete(collection_item)
          end
        end

        non_cached_results = []

        # sequentially render any non-cached objects remaining
        if @collection.any?
          non_cached_results = @template ? collection_with_template : collection_without_template
        end

        # sort the result according to the keys that were fed in, cache the non-cached results
        keys_to_collection_map.each do |key, value|

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

  class Railtie < Rails::Railtie
    initializer "multi_fetch_fragments.initialize" do |app|
      ActionView::PartialRenderer.class_eval do
        include MultiFetchFragments
      end
    end
  end
end

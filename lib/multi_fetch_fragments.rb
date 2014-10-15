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

      if cache_collection?
        cache_options = @options.fetch(:cache_options, {})

        keys_to_item_info_map = {}
        @collection.each_with_index do |item, index|
          key = @options[:cache].respond_to?(:call) ? @options[:cache].call(item) : item

          key = @view.fragment_name_with_digest(key) if @view.respond_to?(:fragment_name_with_digest)

          expanded_key = @view.controller.fragment_cache_key(key)

          keys_to_item_info_map[expanded_key] = item, index
        end

        # cache.read_multi and cache.write interfaces may require mutable keys, ie. dalli 2.6.0
        keys = keys_to_item_info_map.keys.map(&:dup)

        cached_results = @view.controller.instrument_fragment_cache(:read_fragment, keys.join("; ")) do
          cached_results = @view.controller.cache_store.read_multi(*keys, cache_options)

          cached_results.each do |key, result|
            cached_results[key] = result.html_safe if result.respond_to?(:html_safe)
          end

          cached_results
        end

        # if we had a cached value, we don't need to render that object from the collection.
        # if it wasn't cached, we need to render those objects as before
        uncached_keys = keys - cached_results.keys

        # @collection_data is only used if no @path could be found that covers all items
        use_collection_data = @path.nil? && @collection_data

        uncached_collection       = []
        uncached_collection_data  = [] if use_collection_data
        uncached_keys.each do |key|
          item, index = keys_to_item_info_map[key]

          uncached_collection       << item
          uncached_collection_data  << @collection_data[index] if use_collection_data
        end

        @collection       = uncached_collection
        @collection_data  = uncached_collection_data if use_collection_data

        # sequentially render any uncached objects remaining
        uncached_results = []
        unless @collection.empty?
          uncached_results = @template ? collection_with_template : collection_without_template
        end

        # sort the result according to the keys that were fed in, cache the uncached results
        keys.each do |key|
          result = cached_results[key]
          if result.nil?
            result = uncached_results.shift

            @view.controller.instrument_fragment_cache(:write_fragment, key) do
              @view.controller.cache_store.write(key, result.try(:to_str), cache_options)
            end
          end
            
          results << result
        end
      else
        results = @template ? collection_with_template : collection_without_template
      end

      results.join(spacer).html_safe
    end

    def cache_collection?
      cache_option = @options[:cache].presence || @locals[:cache].presence
      @view.controller && @view.controller.perform_caching && @view.controller.cache_store && cache_option
    end

  class Railtie < Rails::Railtie
    initializer "multi_fetch_fragments.initialize" do |app|
      ActiveSupport.on_load(:action_view) do
        ActionView::PartialRenderer.send(:include, MultiFetchFragments)
      end
    end
  end
end

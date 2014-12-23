class BlendedSearch < Search
  include Govboxable

  KLASS_MODULE_MAPPING = { indexed_document: 'AIDOC', news_item: 'NEWS' }

  def initialize(options = {})
    super(options)
    @options = options
    @query = (@query || '').squish
    @total = 0
    @limit = options[:limit]
    @offset = options[:offset]
    @sort = 'published_at:desc' if options[:sort_by] == 'date'
    @highlight_options = options.slice(:pre_tags, :post_tags)
    @highlight_options[:highlighting] = options[:enable_highlighting]
  end

  def search
    search_options = {
      affiliate_id: @affiliate.id,
      language: @affiliate.locale,
      offset: detect_offset,
      q: @query,
      rss_feed_url_ids: @affiliate.rss_feed_urls.pluck(:id),
      size: detect_size,
      sort: @sort,
    }.reverse_merge(@highlight_options)

    elastic_blended_results = ElasticBlended.search_for(search_options)
    ensure_no_suggestion_when_results_present(elastic_blended_results)
    if elastic_blended_results && elastic_blended_results.total.zero? && elastic_blended_results.suggestion.present?
      suggestion = elastic_blended_results.suggestion
      elastic_blended_results = ElasticBlended.search_for(search_options.merge(q: suggestion.text))
      elastic_blended_results.override_suggestion(suggestion) if elastic_blended_results
    end
    elastic_blended_results
  end

  def detect_size
    @limit ? @limit : @per_page
  end

  def detect_offset
    @offset ? @offset : ((@page - 1) * @per_page)
  end

  def handle_response(response)
    if response
      @total = response.total
      ResultsWithBodyAndDescriptionPostProcessor.new(response.results).post_process_results
      @results = paginate(response.results)
      @startrecord = ((@page - 1) * @per_page) + 1
      @endrecord = @startrecord + @results.size - 1
      @spelling_suggestion = response.suggestion.highlighted if response.suggestion.present?
    end
  end

  def first_page?
    @offset ? @offset.zero? : super
  end

  protected
  def populate_additional_results
    @govbox_set = GovboxSet.new(query,
                                affiliate,
                                @options[:geoip_info],
                                @highlight_options) if first_page?
  end

  def log_serp_impressions
    @modules << "LOVER" << "SPEL" unless self.spelling_suggestion.nil?
    @modules |= (@govbox_set.modules - %w(NEWS)) if @govbox_set
    @modules << modules_in_results if @total > 0
  end

  private

  def modules_in_results
    @results.collect { |result| result.class.name.underscore.to_sym }.uniq.map { |sym| KLASS_MODULE_MAPPING[sym] }
  end

  def ensure_no_suggestion_when_results_present(elastic_blended_results)
    if elastic_blended_results && elastic_blended_results.total > 0 && elastic_blended_results.suggestion.present?
      elastic_blended_results.override_suggestion(nil)
    end
  end
end

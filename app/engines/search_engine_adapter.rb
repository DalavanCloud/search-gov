require 'forwardable'

class SearchEngineAdapter
  extend Forwardable

  def initialize(klass, options)
    @options = options
    @affiliate = @options[:affiliate]
    @page = @options[:page]
    @per_page = @options[:per_page]
    @offset = (@options[:page] - 1) * @options[:per_page]
    @query = @options[:query]
    @site_limits = @options[:site_limits]

    @search_engine = klass.new search_params
    @search_engine_response = SearchEngineResponse.new
  end

  def_instance_delegators :@search_engine_response,
                          :total,
                          :spelling_suggestion

  def_instance_delegator :@search_engine_response, :start_record, :startrecord
  def_instance_delegator :@search_engine_response, :end_record, :endrecord

  def run
    instrument_name = "#{@search_engine.class.name.tableize.singularize}.usasearch"
    ActiveSupport::Notifications.instrument(instrument_name,
                                            query: { term: @search_engine.query }) do
      @search_engine_response = @search_engine.execute_query
    end
  rescue SearchEngine::SearchError => error
    Rails.logger.warn "Error getting image search results from #{@search_engine.class} endpoint: #{error}"
    false
  end

  def results
    @results || (paginate(post_process_results(@search_engine_response.results)) if @search_engine_response.results)
  end

  def paginate(items)
    WillPaginate::Collection.create(@page,
                                    @per_page,
                                    [@per_page * 100, total].min) do |pager|
      pager.replace(items)
    end
  end

  def post_process_results(results)
    results.select { |result| result.thumbnail.present? }
  end

  def default_module_tag
    @search_engine.instance_of?(BingImageSearch) ? 'IMAG' : 'AIMAG'
  end

  def default_spelling_module_tag
    'BSPEL'
  end

  protected

  def search_params
    { language: @affiliate.locale,
      offset: @offset,
      per_page: @per_page,
      query: build_formatted_query }
  end

  def build_formatted_query
    formatted_query_klass = "#{@affiliate.search_engine}FormattedQuery".constantize
    formatted_query_instance = formatted_query_klass.new @query, domains_scope_options
    formatted_query_instance.query
  end

  def domains_scope_options
    DomainScopeOptionsBuilder.build @affiliate, @site_limits
  end

end

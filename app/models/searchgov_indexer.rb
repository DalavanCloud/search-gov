class SearchgovIndexer
    extend Resque::Plugins::Priority
  extend ResqueJobStats
  @queue = :primary
  @@logger = ActiveSupport::BufferedLogger.new(Rails.root.to_s + "/log/SearchgovIndexer.log")
  @@logger.auto_flushing = 1

  #TODO: option to crawl specific filetypes

  def self.perform(domain)
    # crawling options:
    # https://github.com/brutuscat/medusa/blob/master/lib/medusa/core.rb#L28
    options = {
      discard_page_bodies: true,
     # delay: delay,
      obey_robots_txt: true,
      skip_query_strings: true,
      read_timeout: 30,
      threads: 8, #(default is 4),
      verbose: true
    }

    doc_links = Set.new
    site =  HTTP.follow.get("http://#{@domain}").uri.to_s

    Medusa.crawl(site, options) do |medusa|
      medusa.skip_links_like(skiplinks_regex)

       medusa.on_every_page do |page|
        url = (page.redirect_to || page.url).to_s
        if page.code == 200 && page.visited.nil? && supported_content_type(page.headers['content-type'])
          puts "creating su for #{url}".green
          SearchgovUrl.create(url: url)
          links = page.links.map(&:to_s)
          links = links.select{|link| /\.(#{application_extensions.join("|")})/i === link }
          links.each{|link| doc_links << link  }
          links.each{|link| puts "doc: '#{link}'".blue  }
        end
      end
     end

    doc_links.each do |link|
      puts "creating SU for '#{link}"
      SearchgovUrl.create(url: link)
    end

    SearchgovUrl.where("url like '#{site}%' and last_crawl_status is null").find_each do |su|
      puts "indexing #{su.url}".yellow
      su.fetch
    end
  end

  def self.application_extensions
    %w{doc docx pdf xls xlsx ppt pptx}
  end

  def self.skiplinks_regex
    /\.(#{(Fetchable::BLACKLISTED_EXTENSIONS + application_extensions ).join('|')})/i
  end

  def self.supported_content_type(type)
    SearchgovUrl::SUPPORTED_CONTENT_TYPES.any? do |ok_type|
      %r{#{ok_type}} === type
    end
  end
end

require 'filetype'

# coding: utf-8
class IndexedDocument < ActiveRecord::Base
  include Dupable
  include FastDeleteFromDbAndEs

  class IndexedDocumentError < RuntimeError;
  end

  attr_reader :file

  belongs_to :affiliate
  before_validation :normalize_url
  validates_presence_of :url, :affiliate_id
  validates_uniqueness_of :url, :message => "has already been added", :scope => :affiliate_id, :case_sensitive => false
  validates_url :url, allow_blank: true
  validates_length_of :url, :maximum => 2000
  validate :extension_ok

  OK_STATUS = "OK"
  SUMMARIZED_STATUS = 'summarized'
  NON_ERROR_STATUSES = [OK_STATUS, SUMMARIZED_STATUS]
  scope :ok, where(:last_crawl_status => OK_STATUS)
  scope :summarized, where(:last_crawl_status => SUMMARIZED_STATUS)
  scope :not_ok, where("last_crawl_status <> '#{OK_STATUS}' OR ISNULL(last_crawled_at)")
  scope :fetched, where('last_crawled_at IS NOT NULL')
  scope :unfetched, where('ISNULL(last_crawled_at)')
  scope :html, where(:doctype => 'html')
  scope :by_matching_url, -> substring { where("url like ?","%#{substring}%") if substring.present? }

  MAX_DOC_SIZE = 50.megabytes
  DOWNLOAD_TIMEOUT_SECS = 300
  EMPTY_BODY_STATUS = "No content found in document"
  UNSUPPORTED_EXTENSION = "URL extension is not one we index"
  BLACKLISTED_EXTENSIONS = %w{wmv mov css csv gif htc ico jpeg jpg js json mp3 png rss swf txt wsdl xml zip gz z bz2 tgz jar tar m4v}

  def fetch
    Rails.logger.debug "Fetching IndexedDocument #{id}, #{url}"
    destroy and return unless errors.empty?
    begin
      uri = URI(url)
      timeout(DOWNLOAD_TIMEOUT_SECS) do
        self.load_time = Benchmark.realtime do
          Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
            request = Net::HTTP::Get.new uri.request_uri, {'User-Agent' => DEFAULT_USER_AGENT }
            http.request(request) do |response|
              raise IndexedDocumentError.new("#{response.code} #{response.message}") unless response.kind_of?(Net::HTTPSuccess)
              @file = Tempfile.open("IndexedDocument:#{id}", Rails.root.join('tmp'))
              file.set_encoding Encoding::BINARY
              begin
                response.read_body { |chunk| file.write chunk }
                file.flush
                file.rewind
                index_document(file, response.content_type)
              ensure
                file.close
                file.unlink
              end
            end
          end
        end
        save_or_destroy
      end
    rescue Exception => e
      handle_fetch_exception(e)
    end
  end

  def handle_fetch_exception(e)
    begin
      update_attributes!(:last_crawled_at => Time.now, :last_crawl_status => normalize_error_message(e), :body => nil)
    rescue Exception
      begin
        destroy
      rescue Exception
        Rails.logger.warn 'IndexedDocument: Could not destroy record'
      end
    end
  end

  def save_or_destroy
    save!
  rescue Mysql2::Error
    destroy
  rescue ActiveRecord::RecordInvalid
    raise IndexedDocumentError.new("Problem saving indexed document: record invalid")
  end

  def index_document(file, content_type)
    raise IndexedDocumentError.new "Document is over #{MAX_DOC_SIZE/1.megabyte}mb limit" if file.size > MAX_DOC_SIZE
    case content_type
      when /html/
        index_html(file)
      when /pdf/
        index_application_file(file.path, 'pdf')
      when /(ms-excel|spreadsheetml)/
        index_application_file(file.path, 'excel')
      when /(ms-powerpoint|presentationml)/
        index_application_file(file.path, 'ppt')
      when /(ms-?word|wordprocessingml)/
        index_application_file(file.path, 'word')
      else
        raise IndexedDocumentError.new "Unsupported document type: #{file.content_type}"
    end
  end

  def index_html(file)
    doc = Nokogiri::HTML(file)
    doc.css('script').each(&:remove)
    doc.css('style').each(&:remove)
    meta_desc = doc.at('meta[name="description"]')
    description = meta_desc['content'].squish if meta_desc #FIXME
    title = doc.title.squish
    self.attributes = { body: extract_body_from(doc), doctype: 'html', last_crawled_at: Time.now, last_crawl_status: OK_STATUS, 
                        title: title, description: description }
  end

  def index_application_file(file_path, doctype)
    document_text = parse_file(file_path, 't').strip rescue nil
    raise IndexedDocumentError.new(EMPTY_BODY_STATUS) if document_text.blank?
    self.attributes = { :body => scrub_inner_text(document_text), :doctype => doctype,
                        :last_crawled_at => Time.now, :last_crawl_status => OK_STATUS,
                         description: self.description || application_metadata[:description],
                         title: self.title || application_metadata[:title] }
  end

  def extract_body_from(nokogiri_doc)
    body = scrub_inner_text(Sanitize.clean(nokogiri_doc.at('body').inner_html.encode('utf-8'))) rescue ''
    raise IndexedDocumentError.new(EMPTY_BODY_STATUS) if body.blank?
    body
  end

  def scrub_inner_text(inner_text)
    inner_text.gsub(/ |\uFFFD/, ' ').squish.gsub(/[\t\n\r]/, ' ').gsub(/(\s)\1+/, '. ').gsub('&amp;', '&').squish
  end

  def last_crawl_status_error?
    !NON_ERROR_STATUSES.include?(last_crawl_status)
  end

  def self_url
    @self_url ||= URI.parse(self.url) rescue nil
  end

  def source_manual?
    source == 'manual'
  end

  private

  def parse_file(file_path, option)
    %x[cat #{file_path} | java -Xmx512m -jar #{Rails.root.to_s}/vendor/jars/tika-app-1.14.jar --encoding=UTF-8 -#{option}]
  end

  def normalize_url
    return if self.url.blank?
    ensure_http_prefix_on_url
    downcase_scheme_and_host_and_remove_anchor_tags
  end

  def ensure_http_prefix_on_url
    self.url = "http://#{self.url}" unless self.url.blank? or self.url =~ %r{^https?://}i
    @self_url = nil
  end

  def downcase_scheme_and_host_and_remove_anchor_tags
    if self_url
      scheme = self_url.scheme.downcase
      host = self_url.host.downcase
      request = self_url.request_uri.gsub(/\/+/, '/')
      self.url = "#{scheme}://#{host}#{request}"
      @self_url = nil
    end
  end

  def extension_ok
    path = URI.parse(self.url).path rescue ""
    extension = File.extname(path).sub(".", "").downcase
    errors.add(:base, UNSUPPORTED_EXTENSION) if BLACKLISTED_EXTENSIONS.include?(extension)
  end

  def normalize_error_message(e)
    case
      when e.message.starts_with?('redirection forbidden')
        'Redirection forbidden from HTTP to HTTPS'
      when e.message.starts_with?('Mysql2::Error: Duplicate entry')
        'Content hash is not unique: Identical content (title and body) already indexed'
      when e.message.include?('execution expired')
        'Document took too long to fetch'
      else
        e.message
    end
  end

  def application_metadata
    meta_json = parse_file(file.path, 'j')
    if meta_json.present?
      metadata = JSON.parse(meta_json)
      { title: metadata['title'].try(:strip), description: metadata['subject'].try(:strip) }
    else
      { title: nil, description: nil }
    end
  end
end

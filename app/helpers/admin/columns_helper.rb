module Admin::ColumnsHelper
  def conditions_column(record, column)
    if record.is_a?(Watcher)
      record.humanized_alert_threshold
    else
      record[column.name]
    end
  end

  def id_column(record, column)
    if record.is_a?(Affiliate)
      link_to record.id, site_path(record.id), target: '_blank'
    else
      record[column.name]
    end
  end

  def name_column(record, column)
    if record.is_a? RssFeed
      link_to record.name, site_rss_feed_path(record.owner, record.id), target: '_blank'
    else
      record[column.name]
    end
  end

  def owner_column(record, column)
    link_to(record.owner.display_name, site_path(record.owner.id), target: '_blank') if record.owner.is_a?(Affiliate)
  end

  def url_column(record, column)
    link_to_url_without_protocol record.url, target: '_blank'
  end

  def website_column(record, column)
    link_to_url_without_protocol record.website, target: '_blank'
  end

  def nutshell_column(record, column)
    if record.nutshell_id
      if record.is_a?(User)
        link_to(record.nutshell_id, "https://app.nutshell.com/contact/#{record.nutshell_id}", target: '_blank')
      elsif record.is_a?(Affiliate)
        link_to(record.nutshell_id, "https://app.nutshell.com/lead/id/#{record.nutshell_id}", target: '_blank')
      end
    end
  end

  def templates_column(affiliate, column)
    if affiliate.search_consumer_search_enabled
      link_to('Edit Templates',
              admin_affiliate_search_consumer_templates_path(affiliate.id),
              target: '_blank')
    end
  end
end

require 'spec_helper'

describe Sites::ExcludedUrlsController do
  fixtures :users, :affiliates, :memberships
  before { activate_authlogic }

  describe '#index' do
    it_should_behave_like 'restricted to approved user', :get, :index

    context 'when logged in as affiliate' do
      include_context 'approved user logged in to a site'

      let(:excluded_urls) { mock('excluded urls') }

      before do
        site.stub_chain(:excluded_urls, :paginate, :order).and_return(excluded_urls)
        get :index, site_id: site.id
      end

      it { should assign_to(:site).with(site) }
      it { should assign_to(:excluded_urls).with(excluded_urls) }
    end
  end

  describe '#create' do
    it_should_behave_like 'restricted to approved user', :post, :create

    context 'when logged in as affiliate' do
      include_context 'approved user logged in to a site'

      context 'when Excluded URL params are valid' do
        let(:excluded_url) { mock_model(ExcludedUrl, url: 'http://agency.gov/exclude-me.html') }

        before do
          excluded_urls = mock('excluded urls')
          site.stub(:excluded_urls).and_return(excluded_urls)
          excluded_urls.should_receive(:build).
              with('url' => 'http://agency.gov/exclude-me.html').
              and_return(excluded_url)

          excluded_url.should_receive(:save).and_return(true)

          post :create,
               site_id: site.id,
               excluded_url: { url: 'http://agency.gov/exclude-me.html',
                               not_allowed_key: 'not allowed value' }
        end

        it { should assign_to(:excluded_url).with(excluded_url) }
        it { should redirect_to site_filter_urls_path(site) }
        it { should set_the_flash.to('You have added agency.gov/exclude-me.html to this site.') }
      end

      context 'when Excluded URL params are not valid' do
        let(:excluded_url) { mock_model(ExcludedUrl) }

        before do
          excluded_urls = mock('excluded urls')
          site.stub(:excluded_urls).and_return(excluded_urls)
          excluded_urls.should_receive(:build).
              with('url' => '').and_return(excluded_url)

          excluded_url.should_receive(:save).and_return(false)

          post :create,
               site_id: site.id,
               excluded_url: { url: '',
                               not_allowed_key: 'not allowed value' }
        end

        it { should assign_to(:excluded_url).with(excluded_url) }
        it { should render_template(:new) }
      end
    end
  end

  describe '#destroy' do
    it_should_behave_like 'restricted to approved user', :delete, :destroy

    context 'when logged in as affiliate' do
      include_context 'approved user logged in to a site'

      before do
        excluded_urls = mock('excluded urls')
        site.stub(:excluded_urls).and_return(excluded_urls)

        excluded_url = mock_model(ExcludedUrl, url: 'agency.gov/exclude-me.html')
        excluded_urls.should_receive(:find_by_id).with('100').
            and_return(excluded_url)
        excluded_url.should_receive(:destroy)

        delete :destroy, site_id: site.id, id: 100
      end

      it { should redirect_to(site_filter_urls_path(site)) }
      it { should set_the_flash.to('You have removed agency.gov/exclude-me.html from this site.') }
    end
  end
end

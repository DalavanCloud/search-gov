require 'spec_helper'

describe WatcherObserver do
  before do
    @watcher = mock_model(Watcher, id: 123, body: 'body')
    @observer = WatcherObserver.instance
  end

  describe "after_save" do
    it "sets up the watch in Elasticsearch" do
      ES.client_reader.watcher.should_receive(:put_watch).with(id: 123, body: 'body')
      @observer.after_save(@watcher)
    end
  end

  describe "after_destroy" do
    it "deletes the watch in Elasticsearch" do
      ES.client_reader.watcher.should_receive(:delete_watch).with(id: 123, force: true)
      @observer.after_destroy(@watcher)
    end
  end
end
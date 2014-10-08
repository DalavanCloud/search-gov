require 'spec_helper'

describe NewsItemsDestroyer do
  describe '.perform' do
    let(:batch_group) do
      [mock_model(NewsItem, id: 100),
       mock_model(NewsItem, id: 101)]
    end

    let(:ids) { [100, 101].freeze }

    it 'destroy all NewsItems' do
      NewsItem.stub_chain(:where, :select, :find_in_batches).and_yield(batch_group)
      NewsItem.should_receive(:fast_delete).with(ids)

      NewsItemsDestroyer.perform 100
    end
  end
end

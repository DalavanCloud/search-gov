require 'spec_helper'

describe MobileSearchHelper do
  fixtures :affiliates

  describe '#eligible_for_commercial_results?' do
    context 'when search is not ImageSearch or BlendedSearch' do
      it 'returns false' do
        search = mock(LegacyImageSearch, page: 1, per_page: 20, total: 5)
        expect(helper.eligible_for_commercial_results?(search)).to eq(false)
      end
    end
  end

  describe '#extra_pagination_params' do
    let(:search) { ImageSearch.new(affiliate: affiliates(:non_existent_affiliate), query: 'corgi') }
    before { search.stub(:module_tag).and_return('IMAG') }

    it 'returns cr:true for IMAG ImagSearch instances' do
      expect(helper.extra_pagination_params(search)).to eq({ cr: true })
    end
  end
end

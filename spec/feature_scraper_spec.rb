require 'feature_scraper'

describe FeatureScraper do

  let(:scraper) { FeatureScraper.new 'http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyMappingOL/MapServer/0' }
  let(:bad_url_scraper) { FeatureScraper.new 'garbage' }
  let(:odd_pk_scraper) { FeatureScraper.new 'http://gps.digimap.gg/arcgis/rest/services/JerseyUtilities/JerseyUtilities/MapServer/145' }

  context '#new(url)' do
    it 'instantiates an instance of the class' do
      expect(scraper.class).to eq FeatureScraper
    end
  end

  context '#name' do
    it 'returns the name of the layer' do
      expect(scraper.send :name). to eq 'Gazetteer'
    end
  end

  context '#pk' do
    it 'returns the "primary key" field for the layer, if it is first in the field list' do
      expect(scraper.send :pk).to eq 'OBJECTID'
    end

    it 'returns the "primary key" field for the layer, if it is elsewhere in the field list' do
      expect(odd_pk_scraper.send :pk).to eq 'OBJECTID'
    end
  end

  context '#max' do
    it 'returns the "maxRecordCount" value for the layer' do
      expect(scraper.send :max).to eq 1000
    end
  end

  context '#form' do
    it 'returns a Mechanize::Form for the layer query page' do
      expect(scraper.send(:form).class).to eq Mechanize::Form
    end
  end

   context '#count' do
    it 'returns the number of records for the layer' do
      expect(scraper.send :count).to eq 67537
    end
  end

  context '#data(records_set_num)' do
    it 'returns a hash of json data with no args' do
      expect(scraper.send(:data, 0).class).to eq Hash
    end

    it 'returns data for the set of records' do
      expect(scraper.send(:data, 67)['features'].count).to eq 537
    end
  end

  context '#features' do
    it 'returns an array of the features data for all layer objects' do
      scraper.instance_variable_set(:@max, 2)
      allow(scraper).to receive(:count) { 4 }
      expect(scraper.send(:features).count).to eq 4
    end
  end

  context '#json_data', :public do
    it 'returns string of json data for all layer objects' do
      scraper.instance_variable_set(:@max, 2)
      allow(scraper).to receive(:count) { 4 }
      expect(scraper.json_data.class).to eq String
    end
  end

end

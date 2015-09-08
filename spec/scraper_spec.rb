require 'scraper'

describe Scraper do

  let(:scraper) { Scraper.new('StatesOfJersey/JerseyMappingOL', 0) }

  context '#new(service, layer_num)' do
    it 'instantiates an instance of the class' do
      expect(scraper.class).to eq Scraper
    end
  end

  context '#new(service, layer_num)' do
    it 'instantiates an instance of the class' do
      expect(scraper.url).to eq 'http://gps.digimap.gg/arcgis/rest/services/StatesOfJersey/JerseyMappingOL/MapServer/0'
    end
  end

  context '#pk' do
    it 'returns the "primary key" field for the layer' do
      expect(scraper.pk).to eq 'OBJECTID'
    end
  end

  context '#max' do
    it 'returns the "maxRecordCount" value for the layer' do
      expect(scraper.max).to eq 1000
    end
  end

  context '#form' do
    it 'returns a Mechanize::Form for the layer query page' do
      expect(scraper.form.class).to eq Mechanize::Form
    end
  end

   context '#count' do
    it 'returns the number of records for the layer' do
      expect(scraper.count).to eq 67537
    end
  end

  context '#data(records_set_num)' do
    it 'returns a hash of json data with no args' do
      expect(scraper.data(0).class).to eq Hash
    end

    it 'returns data for the set of records' do
      puts scraper.data(68).keys
      expect(scraper.data(68)['features'].count).to eq 537
    end
  end

end

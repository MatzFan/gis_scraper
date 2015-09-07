require 'scraper'

describe Scraper do

  context '#new' do
    it 'instantiated an instance of the class' do
      expect(Scraper.new.class).to eq Scraper
    end
  end

end

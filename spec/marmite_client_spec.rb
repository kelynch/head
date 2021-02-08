# frozen_string_literal: true

RSpec.describe MarmiteClient do
  describe '#marc21' do
    let(:bibnumber) { '9923478503503681' }

    context 'when request is successful' do
      before do
        stub_request(:get, "https://marmite.library.upenn.edu:9292/records/#{bibnumber}/create?format=marc21").to_return(status: 302)
        stub_request(:get, "https://marmite.library.upenn.edu:9292/records/#{bibnumber}/show?format=marc21")
          .to_return(status: 200, body: fixture_to_str('marmite', 'marc_xml', "#{bibnumber}.xml"), headers: {})
      end

      it 'returns expected MARC XML' do
        expect(described_class.marc21(bibnumber)).to eql fixture_to_str('marmite', 'marc_xml', "#{bibnumber}.xml")
      end
    end

    context 'when request is unsuccessful' do
      before do
        stub_request(:get, "https://marmite.library.upenn.edu:9292/records/#{bibnumber}/create?format=marc21").to_return(status: 302)
        stub_request(:get, "https://marmite.library.upenn.edu:9292/records/#{bibnumber}/show?format=marc21")
          .to_return(status: 404, body: "Record #{bibnumber} in marc21 format not found", headers: {})
      end

      it 'raises exception' do
        expect {
          described_class.marc21(bibnumber)
        }.to raise_error(MarmiteClient::Error, "Could not retrieve MARC for #{bibnumber}. Error: Record #{bibnumber} in marc21 format not found")
      end
    end
  end

  describe '#config' do
    context 'when all configuration is present' do
      it 'returns configuration' do
        expect(described_class.config).to eql('url' => 'https://marmite.library.upenn.edu:9292')
      end
    end

    context 'when missing url' do
      before do
        allow(Rails.application).to receive(:config_for).with(:bulwark).and_return('marmite' => {})
      end

      it 'raises error' do
        expect { described_class.config }.to raise_error MarmiteClient::MissingConfiguration, 'Missing Marmite URL'
      end
    end
  end
end

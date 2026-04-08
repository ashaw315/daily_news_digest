require 'rails_helper'

RSpec.describe ArticleClassifierService do
  let(:service) { described_class.new }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('test-key')
  end

  def stub_openai_response(content)
    response = { "choices" => [{ "message" => { "content" => content } }] }
    allow_any_instance_of(OpenAI::Client).to receive(:chat).and_return(response)
  end

  describe '#classify' do
    it 'returns a valid category from the allowed list' do
      stub_openai_response("Technology")

      result = service.classify(title: "New AI chip released", summary: "A faster processor")
      expect(ArticleClassifierService::CATEGORIES).to include(result)
      expect(result).to eq("Technology")
    end

    it 'returns "World" when the API call fails' do
      allow_any_instance_of(OpenAI::Client).to receive(:chat).and_raise(StandardError.new("API down"))

      result = service.classify(title: "Breaking news", summary: "Something happened")
      expect(result).to eq("World")
    end

    it 'returns "World" when the API returns an unrecognized value' do
      stub_openai_response("Entertainment")

      result = service.classify(title: "Movie review", summary: "A new film")
      expect(result).to eq("World")
    end

    it 'strips whitespace from the response' do
      stub_openai_response("  Science  \n")

      result = service.classify(title: "New discovery", summary: "Scientists found something")
      expect(result).to eq("Science")
    end

    it 'handles case-insensitive matching' do
      stub_openai_response("business")

      result = service.classify(title: "Stock market", summary: "Markets rose today")
      expect(result).to eq("Business")
    end

    it 'returns "World" when both title and summary are blank' do
      result = service.classify(title: "", summary: "")
      expect(result).to eq("World")
    end
  end
end

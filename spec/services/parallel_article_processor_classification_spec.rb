require 'rails_helper'

RSpec.describe ParallelArticleProcessor, 'classification integration' do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('test-key')

    # Stub AI summarizer to return a simple summary
    allow_any_instance_of(AiSummarizerService).to receive(:generate_summary)
      .and_return("A test summary of the article content.")

    # Stub classifier to return a known category
    allow_any_instance_of(ArticleClassifierService).to receive(:classify)
      .and_return("Technology")
  end

  let(:processor) { described_class.new }

  let(:articles) do
    [
      {
        title: "New AI Breakthrough",
        url: "https://example.com/ai",
        content: "Researchers have developed a new AI model that can process language faster.",
        published_at: Time.current,
        source: "Tech News"
      }
    ]
  end

  it 'sets article topic to one of the allowed categories' do
    results = processor.process_articles(articles)

    expect(results.length).to eq(1)
    expect(ArticleClassifierService::CATEGORIES).to include(results.first[:topic])
    expect(results.first[:topic]).to eq("Technology")
  end

  it 'still saves the summary when classification fails' do
    allow_any_instance_of(ArticleClassifierService).to receive(:classify)
      .and_raise(StandardError.new("classifier down"))

    results = processor.process_articles(articles)

    expect(results.length).to eq(1)
    expect(results.first[:summary]).to be_present
    expect(results.first[:topic]).to be_present # falls back to extract_existing_topic
  end

  it 'updates the database record when processing an Article model' do
    news_source = create(:news_source)
    article = create(:article, news_source: news_source, topic: nil)

    results = processor.process_articles([article])

    expect(results.length).to eq(1)
    expect(article.reload.topic).to eq("Technology")
  end
end

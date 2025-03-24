# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
# Create initial topics
topics = ['Technology', 'Science', 'Business', 'Health', 'Sports', 'Politics', 'Entertainment', 'World']
topics.each do |topic|
  Topic.find_or_create_by(name: topic.downcase)
end

# Create initial sources
sources = ['News API', 'Reuters', 'Associated Press', 'BBC', 'CNN', 'New York Times']
sources.each do |source|
  Source.find_or_create_by(name: source, url: "https://example.com/#{source.parameterize}", source_type: 'rss', active: true)
end
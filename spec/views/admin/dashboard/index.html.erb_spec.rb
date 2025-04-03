require 'rails_helper'

RSpec.describe "admin/dashboard/index", type: :view do
  before do
    assign(:user_count, 10)
    assign(:topic_count, 5)
    assign(:source_count, 3)
    assign(:recent_users, [])
    assign(:recent_emails, [])
  end

  it "renders the dashboard" do
    render
    expect(rendered).to match(/Dashboard/)
    expect(rendered).to match(/10/)  # User count
    expect(rendered).to match(/5/)   # Topic count
    expect(rendered).to match(/3/)   # Source count
  end
end
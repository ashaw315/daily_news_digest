require 'rails_helper'

RSpec.describe "Smoke test" do
  it "has a valid database connection" do
    expect { ActiveRecord::Base.connection.execute("SELECT 1") }.not_to raise_error
  end

  it "can connect to Rails environment" do
    expect(Rails.env).to be_present
  end
end
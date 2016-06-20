require 'rails_helper'

RSpec.describe Manuscript, type: :model do
  it "has a valid Factory" do
    expect(FactoryGirl.create(:manuscript)).to be_valid
  end
  it "is invalid without a title" do
    expect(FactoryGirl.build(:manuscript, :title => nil)).not_to be_valid
  end
  it "is invalid without an identifier" do
    expect(FactoryGirl.build(:manuscript, :identifier => nil)).not_to be_valid
  end
end
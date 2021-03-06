require 'rails_helper'
RSpec.feature 'AffiliationAutofill', type: :feature do

  include DatasetHelper
  include Mocks::RSolr
  include Mocks::Ror
  include Mocks::Tenant

  before(:each) do
    mock_solr!
    mock_ror!
    mock_tenant!
    @user = create(:user)
    sign_in(@user)
  end

  context :ror_api do

    before(:each) do
      start_new_dataset
    end

    it 'displays affiliation choices from the ROR API', js: true do
      fill_in 'author[affiliation][long_name]', with: 'Testing'
      expect(page).to have_text('University of Testing')
      expect(page).to have_text('University of Testing v2')
    end

    it 'sets the ROR id when user selects an option', js: true do
      stub_ror_id_lookup(university: 'University of Testing v2')
      fill_in 'author[affiliation][long_name]', with: 'Testing'
      first('.ui-menu-item-wrapper', wait: 1).click
      expect(find('#author_affiliation_ror_id', visible: false).value).to eql('https://ror.org/TEST2')
    end

    it 'allows entries that are not registered with ROR', js: true do
      fill_in 'author[affiliation][long_name]', with: 'Testing a non-ROR organization'
      expect(find('#author_affiliation_ror_id', visible: false).value).to eql('')
    end

    it 'allows changing from a ROR-based value to a non-ROR value', js: true do
      stub_ror_id_lookup(university: 'University of Testing v2')
      fill_in 'author[affiliation][long_name]', with: 'Testing'
      first('.ui-menu-item-wrapper', wait: 1).click
      expect(find('#author_affiliation_ror_id', visible: false).value).to eql('https://ror.org/TEST2')
      fill_in 'author[affiliation][long_name]', with: 'Testing a non-ROR organization'
      expect(find('#author_affiliation_ror_id', visible: false).value).to eql('')
    end

  end

end

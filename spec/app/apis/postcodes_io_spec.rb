# frozen_string_literal: true

require 'rails_helper'

describe PostcodesIo do

# Add VCR cassette

    let(:postcode) { 'SE1 0EZ' }

    it 'calls the' do
        subject.call(postcode)
        expect( a_request(:get, "http://postcode.io/#{postcode}")).to have_been_made.once  
    end
end
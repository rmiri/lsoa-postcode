
require 'httparty'

class PostcodesIo
    include httparty

    BASE_URI = 'postcode.io/'
    private_constant: :BASE_URI

    def self.call(postcode)
        get(BASE_URI+postcode)
    end

end
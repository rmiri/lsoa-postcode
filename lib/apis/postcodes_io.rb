
require 'httparty'

class PostcodesIo
    include httparty

    BASE_URI = 'postcode.io'
    private_constant: :BASE_URI

    

end
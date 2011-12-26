require 'location/persistant_hash'

class Credentials < PersistantHash
    # handle access to credentials.yml
    def initialize(filepath = nil)
        super(filepath || 'credentials.yaml')
    end
    def clear_request
        delete :request_token
        delete :request_token_secret
    end
    def update_request_token(resp)
        merge!(:request_token => resp.token,
            :request_token_secret => resp.secret)
    end
    def update_access_token(resp)
        merge!(:access_token => resp.token,
            :access_token_secret => resp.secret)
    end
end

require 'fireeagle'
require 'location/credentials'

class FireEagleService
    # handle access to fire eagle service
    attr_writer :credentials
    attr_accessor :callback_url
    def initialize
        @callback_url = nil
    end
    def credentials
        @cred ||= Credentials.load
    end
    def client
        @client ||= FireEagle::Client.new(credentials)
    end
    def self.get_locations
        self.new.locations
    end
    def self.update
        self.new.update
    end
    def locations
        client.user.locations
    end
    def has_credentials?
        Credentials.new.exists?
    end
    def request_authorization
        begin
            credentials.clear_request
            @client = FireEagle::Client.new(credentials)
            resp = @client.get_request_token(callback_url)
            credentials.update_request_token(resp)
            credentials.save
        rescue OAuth::Unauthorized
            raise InvalidCredentials
        end
    end
    def authorization_url
        require 'cgi'
        callback_query = callback_url.nil? ? "" : "&oauth_callback="+CGI.escape(callback_url)
        client.authorization_url + callback_query
    end
    def update_authorization(oauth_verifier)
        resp = client.convert_to_access_token(oauth_verifier)
        credentials.update_access_token(resp)
        credentials.clear_request
        credentials.save
    end
end

class InvalidCredentials < Exception; end

#!/usr/bin/env ruby

# Location
#
# A smart resource that manages your location
# plays nice with Fire Eagle
# provides a simple way for systems to get current location

require 'sinatra'
require 'active_support/time'

class Array
    def merge
        self.inject({}) do |hash, item|
            hash.merge(yield(item))
        end
    end
end

class PersistantHash < Hash
    require 'yaml'
    attr_accessor :filepath
    def initialize(filepath)
        @filepath = filepath
    end
    def self.load(filepath = nil)
        p = self.new(filepath)
        p.load
    end
    def load
        stored = YAML.load_file @filepath
        clear
        merge!(stored)
    end
    def save
        File.open(@filepath, 'w') {|f|
            YAML.dump(self, f)
        }
    end
end

class Location < PersistantHash
    def initialize(filepath = nil)
        super(filepath || 'location.yaml')
    end
    def self.get_current
        self.new.get_current
    end
    def get_current
        locations = FireEagleService.get_locations
        update_from_locations(locations)
    end
    def update_from_locations(locations)
        clear
        merge!(from_fire_eagle(locations))
    end
    def from_fire_eagle(fe_loc)
        best = pick_best(fe_loc)
        {
            :date => best.located_at,
            :geo => get_geo(best),
            :adr => get_adr(fe_loc)
        }
    end
    def pick_best(locations)
        locations.find {|l| l.best_guess }
    end
    def get_adr(locations)
        levels = [:country, :state, :city, :neighborhood]
        levels.merge do |level|
            { level => get_name_by_level(locations, level)}
        end
    end
    def get_name_by_level(locations, level)
        locations.find {|l|
            l.level_name == level.to_s
        }.normal_name
    end
    def get_geo(location)
        geo = location.geo
        {
            :long => geo.x,
            :lat => geo.y
        }
    end
end

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

class FireEagleService
    # handle access to fire eagle service
    require 'fireeagle'
    attr_accessor :cred
    def initialize
        @cred = Credentials.load
        @client = FireEagle::Client.new(@cred)
    end
    def self.get_locations
        self.new.locations
    end
    def self.update
        self.new.update
    end
    def locations
        @client.user.locations
    end
    def request_authorization(callback_url='')
        begin
            @cred.clear_request
            @client = FireEagle::Client.new(@cred)
            resp = @client.get_request_token(callback_url)
            @cred.update_request_token(resp)
            @cred.save
        rescue OAuth::Unauthorized
            raise Location::AuthorizationError, "Bad consumer key"
        end
    end
    def authorization_url(callback_url=nil)
        require 'cgi'
        callback_query = callback_url.nil? ? "" : "&oauth_callback="+CGI.escape(callback_url)
        @client.authorization_url + callback_query
    end
    def update_authorization(oauth_verifier)
        resp = @client.convert_to_access_token(oauth_verifier)
        @cred.update_access_token(resp)
        @cred.clear_request
        @cred.save
    end
end

get '/' do
  begin
    if params[:oauth_verifier]
      svc = FireEagleService.new
      svc.update_authorization(params[:oauth_verifier])
    end
    @location = Location.get_current
  rescue FireEagle::ArgumentError, FireEagle::FireEagleException, OAuth::Unauthorized
    svc = FireEagleService.new
    url = 'http://' + Sinatra::Application.host
    url += ":#{Sinatra::Application.port}" unless Sinatra::Application.port == 80
    svc.request_authorization(url)
    auth_url = svc.authorization_url
    redirect auth_url
  else
    erb :index
  end
end

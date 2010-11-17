#!/usr/bin/env ruby

# Location
#
# A smart resource that manages your location
# plays nice with Fire Eagle
# provides a simple way for systems to get current location

# FIXME: hack to fix oauth
module OAuth
  VERSION = "0.4.4"
end
# end FIXME

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
    def exists?
      File.exists? @filepath
    end
    def load
        stored = YAML.load_file @filepath
        raise "Looks like your yaml file couldn't load: #{@filepath}" unless stored
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
    attr_accessor :credentials, :callback_url
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

get '/' do
  redirect '/credentials' unless FireEagleService.new.has_credentials?
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
    svc.callback_url = url
    begin
      svc.request_authorization
    rescue InvalidCredentials
      redirect '/credentials'
    end
    auth_url = svc.authorization_url
    redirect auth_url
  else
    erb :index
  end
end

get '/credentials' do
  begin
    @credentials = Credentials.load
    @flash = "Looks like these credentials didn't work. Care to double check them?"
  rescue
    @credentials = Credentials.new
    @flash = "Looks like you haven't got your credentials set up. Head over to fire eagle and enter them below."
  end
  erb :first_run
end

post '/credentials' do
  credentials = Credentials.new
  credentials[:consumer_key] = params['consumer_key']
  credentials[:consumer_secret] = params['consumer_secret']
  credentials.save
  redirect '/'
end

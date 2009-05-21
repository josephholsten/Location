#!/usr/bin/env ruby

# Location
#
# A smart resource that manages your location
# plays nice with Fire Eagle
# provides a simple way for systems to get current location

require 'camping'

Camping::goes :Location

class Array
    def merge
        self.inject({}) do |hash, item|
            hash.merge(yield(item))
        end
    end
end

module Location
	class AuthorizationError < SecurityError; end
    module Models
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
				begin
					@client.user.locations
				rescue FireEagle::ArgumentError, FireEagle::FireEagleException
					update_authorization
				# FireEagle::ArgumentError
				#   no access_token, access_token_secret
                # can't recover from FireEagle::FireEagleException here
				#   invalid sig: bad a_token_sec, consumer_sec
				#   token not found: bad a_token
				#   unknown consumer key: bad consumer_key
				#   Token not found: no access_token
				end
			end
			def request_authorization
				begin
					@cred.clear_request
					resp = @client.get_request_token
					@cred.update_request_token(resp)
					@cred.save
				rescue OAuth::Unauthorized
					raise Location::AuthorizationError, "Bad consumer key"
				end
					
			end
			def authorization_url
				@client.authorization_url
			end
            def update_authorization
                resp = @client.convert_to_access_token
                @cred.update_access_token(resp)
                @cred.clear_request
                @cred.save
            end
        end
    end

    module Controllers
        class Index
            def get
				begin
					@location = Location.get_current
				rescue FireEagle::ArgumentError, FireEagle::FireEagleException
					svc = FireEagleService.new
					svc.request_authorization
					redirect svc.authorization_url
				end
				render :index
            end
        end
        class Authentication
            def get
                redirect Index
            end
        end
    end

    module Views
        def layout
            html do
                head do
                    title 'Location'
                    link :rel => 'stylesheet', :type => 'text/css', 
                    :href => '/styles.css', :media => 'screen'
                end
                body do
                    h1 { a 'Location', :href => R(Index) }
                    div.wrapper! do
                        text yield
                    end
                end
            end
        end
        def index
			_adr(@location[:adr])
			_geo(@location[:geo])
_date(@location[:date])
        end
		def _adr(adr)
			div.adr do
				text adr[:neighborhood]
				text ", "
				span.locality {adr[:city]}
				text ", "
				span.region adr[:state]
				text ", "
				span.country_name adr[:country]
			end
		end
		def _geo(geo)
            div.geo do
				span.latitude geo[:lat]
				text ", "
				span.longitude geo[:long]
			end
		end
		def _date(date)
			abbr.dtstarted date.to_date.to_s(:long), :title => date.iso8601
		end
    end
end

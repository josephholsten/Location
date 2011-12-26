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

$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)

require 'sinatra'
require 'active_support/time'
require 'location'

set :views, File.dirname(__FILE__) + '/views' # FIXME: why doesn't the default work with bundler?
enable :logging

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

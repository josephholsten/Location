#\ -w -p 4567
require 'sinatra'

set :host, 'localhost'
set :port, 4567
require 'location'

run Sinatra::Application
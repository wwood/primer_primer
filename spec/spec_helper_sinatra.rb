require 'sinatra'
require 'rack/test'
require 'test/unit'

require File.join(File.dirname(__FILE__), '..', 'primer_primer')

set :environment, :test
set :run, false
set :raise_errors, true
set :logging, false


require 'rubygems'
require 'bundler'
Bundler.setup
require 'minitest/autorun'
require 'sqlite3'
require 'active_record'
require 'bitmask_attributes'
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)
require 'support/models'

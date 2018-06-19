# stubs for 'global' Robe methods which are defined
# as methods of Robe module to provide a short cut to
# global modules or class instances.
#
# TODO: review which are strictly necessary

module Robe
  module_function

  if RUBY_PLATFORM == 'opal'
    # client
    def app;            nil end   # => Robe::Client::App instance
    def browser;        nil end   # => Robe::Client::Browser
    def db;             nil end   # => Robe::Client::DB
    def document;       nil end   # => $document from opal-browser
    def dom;            nil end   # => Robe::Client::Browser::DOM module
    def http;           nil end   # => Robe::Client::Browser::HTTP module
    def logger;         nil end   # => Robe::Logger instance in 'robe/client/util/logger'
    def sockets;        nil end   # => Robe::Client::Server::Sockets.instance
    def tasks;          nil end   # => Robe::Client::Server::Tasks module
    def window;         nil end   # => $window from opal-browser
  else
    # server
    def app;            nil end   # => Robe::Server::App instance
    def auth;           nil end   # => Robe::Server::Auth module
    def config;         nil end   # => Robe::Server::Config class
    def logger;         nil end   # => Robe::Logger instance in 'robe/server/util/logger'
    def db;             nil end   # => Robe::Server::DB
    def http;           nil end   # => Robe::Server::Rack::Http.instance
    def redis;          nil end   # => ::Redis in 'robe/server/redis'
    def sockets;        nil end   # => Robe::Server::Rack::Sockets.instance
    def task_logger;    nil end   # => Robe::Server::Tasks::Logger module
    def task_manager;   nil end   # => Robe::Server::Tasks::Manager instance
    def task_registry;  nil end   # => Robe::Server::Tasks::Registry instance
    def thread;         nil end   # => Robe::Server::Thread module
  end

end

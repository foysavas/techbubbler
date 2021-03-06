# Copyright 2011 Salvatore Sanfilippo. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
#    1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 
#    2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY SALVATORE SANFILIPPO ''AS IS'' AND ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
# NO EVENT SHALL SALVATORE SANFILIPPO OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# The views and conclusions contained in the software and documentation are
# those of the authors and should not be interpreted as representing official
# policies, either expressed or implied, of Salvatore Sanfilippo.

require 'rubygems'
require 'bundler'
RACK_ENV = ENV['RACK_ENV'] ? ENV['RACK_ENV'].to_sym : :development
Bundler.require(:default, RACK_ENV)
require 'digest/sha1'
require 'digest/md5'

require './app_config'
require './config/twitter'
require './page'
require './comments'
require './pbkdf2'

require 'openssl' if UseOpenSSL

use Rack::Session::Cookie
use OmniAuth::Builder do
  provider :twitter, $twitter_options[:consumer_key], $twitter_options[:consumer_secret]
end

Twitter.configure do |config|
  config.consumer_key = $twitter_options[:consumer_key]
  config.consumer_secret = $twitter_options[:consumer_secret]
end

%w(get post).each do |method|
  send(method, "/auth/twitter/callback") do
    auth_token,err = find_or_create_twitter_user(request.env['omniauth.auth'])
    if auth_token
      session['auth'] = auth_token
      redirect '/'
    else
      redirect '/'
    end
  end
end


configure :development do
  use Rack::Reloader
end

configure do
  Compass.configuration do |config|
    config.project_path = File.dirname(__FILE__)
    config.sass_dir     = File.join('views/stylesheets')
    config.images_dir = File.join('public')
  end
  set :haml, { :format => :html5 }
  set :scss, Compass.sass_engine_options.merge(:style => :compressed)
end

get "/stylesheets/compiled/:fn.css" do
  if !File.exists? "views/stylesheets/#{params[:fn]}.scss"
    halt(404,"404 - Not found.")
  end
  r = scss :"stylesheets/#{params[:fn]}"
  if settings.environment == :production
    FileUtils.mkdir_p "public/stylesheets/compiled"
    File.open("public/stylesheets/compiled/#{params[:fn]}.css", "w") do |f|
      f.write r
    end
  end
  content_type 'text/css', :charset => 'utf-8'
  r
end



before do
  $r = Redis.new(:host => RedisHost, :port => RedisPort) if !$r
  H = HTMLGen.new if !defined?(H)
  if !defined?(Comments)
    Comments = RedisComments.new($r,"comment",proc{|c,level|
      c.sort {|a,b|
        ascore = compute_comment_score a
        bscore = compute_comment_score b
        if ascore == bscore
          # If score is the same favor newer comments
          b['ctime'].to_i <=> a['ctime'].to_i
        else
          # If score is different order by score.
          # FIXME: do something smarter favouring newest comments
          # but only in the short time.
          bscore <=> ascore
        end
      }
    })
  end
  $user = nil
  $user = find_session_user(session['auth'])
  if $user
    increment_karma_if_needed
    $user_twitter_client = Twitter::Client.new(
      :oauth_token => $user['twitter_access_token'],
      :oauth_token_secret => $user['twitter_access_secret']
    )
  else
    session['auth'] = nil
    $user_twitter_client = nil # Twitter::Client.new
  end
end

get '/view/:id' do
  url = $r.hget("news:#{params[:id]}",'url')
  if url.match(/^text:\/\//)
    redirect "/news/#{id}"
  elsif url.length > 1
    redirect url
  else
    redirect '/'
  end
end

get '/discuss/:id' do
  redirect "/news/#{params[:id]}"
end


require './views'
require './api'
require './backend'
require './helpers'

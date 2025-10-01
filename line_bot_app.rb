
require 'rubygems'
require 'bundler/setup'
require 'sinatra/base'
require 'json'
require 'httpclient'
require 'sinatra/reloader'
require 'active_record'
require 'mysql2'
require 'twitter'
require 'yaml'

require_relative 'lib/npb/roster_fetcher'

ActiveRecord::Base.configurations = YAML.load_file('db/database.yml')
ActiveRecord::Base.establish_connection(:development)

class LineBotApp < Sinatra::Base
  configure do
    set :views, File.expand_path('views', __dir__)
  end

  class TwitterFollow < ActiveRecord::Base
  end

  get '/' do
    redirect '/npb'
  end

  get '/npb' do
    erb :npb
  end

  get '/npb/data' do
    content_type :json, charset: 'utf-8'
    begin
      payload = Npb::RosterFetcher.fetch
      JSON.pretty_generate(payload)
    rescue Npb::RosterFetcher::FetchError => e
      status 502
      JSON.pretty_generate({ error: e.message })
    end
  end

  post '/callback' do

    CONSUMER_KEY         = "vk6EQeteBFrsmEn9TyoEzCgOR"
    CONSUMER_SECRET      = "Q4zXS4rDFSk2ydOzQaFSjZD6Y6DbO03hKnTpVCzVUTrEY2aN9r"
    ACCESS_TOKEN         = "9257722-gxuj2mQUEUPj7MH7cIQfOc92XVXcw95NduTbrIaz6k"
    ACCESS_TOKEN_SECRET  = "AHrF5zKVUTMlqmkOz7ksO7KFhzJy13qNTPj0UA1gdnNWb"

    restclient = Twitter::REST::Client.new do |config|
      config.consumer_key        = CONSUMER_KEY
      config.consumer_secret     = CONSUMER_SECRET
      config.access_token        = ACCESS_TOKEN
      config.access_token_secret = ACCESS_TOKEN_SECRET
    end
    
    params = JSON.parse(request.body.read)

    params['result'].each do |msg|
      tf = TwitterFollow.find_or_create_by(mid: msg['content']['from'])
      text = msg['content']['text']
      if text == "c"
        tf.tid = nil
        tf.name = nil
        tf.save
        system('./linebot.sh restart || ./linebot.sh start')
        msg['content']['text'] = "クリアしたよ！"
      else
        begin
          user = restclient.user(msg['content']['text'])
        rescue
        end
        if user  
          ids = tf.tid ? tf.tid.split(",") : [] 
          ids << user.id.to_s unless ids.include?(user.id.to_s)
          names = tf.name ? tf.name.split(",") : []
          names << user.name unless names.include?(user.name)
          
          tf.tid = ids.join(",")
          tf.name = names.join(",")
          tf.save
          system('./linebot.sh restart || ./linebot.sh start')
          msg['content']['text'] = <<-"EOS"
ふぉろー追加したよ。
#{tf.name}
EOS
        else
          msg['content']['text'] = <<"EOS"
#{msg['content']['text']}というidは無いね。
#{tf.name}
EOS
        end
      end
      request_content = {
        to: [msg['content']['from']],
        toChannel: 1383378250, # Fixed  value
        eventType: "138311608800106203", # Fixed value
        content: msg['content']
      }
      http_client = HTTPClient.new
      endpoint_uri = 'https://trialbot-api.line.me/v1/events'
      content_json = request_content.to_json
      http_client.post_content(endpoint_uri, content_json,
          'Content-Type' => 'application/json; charset=UTF-8',
          'X-Line-ChannelID' => '1463167898',
          'X-Line-ChannelSecret' => 'e7ac3a3a35dca5e0e456e02be4894e1b',
          'X-Line-Trusted-User-With-ACL' => 'u3eb7467cd18f1dbdaa2b51c07ccc19b6'
      )
    end
  end
end


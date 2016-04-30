
require 'rubygems'
require 'bundler/setup'
require 'twitter'
require 'active_record'
require 'mysql2'
 
require 'parallel'
require 'line/bot'

CONSUMER_KEY         = "vk6EQeteBFrsmEn9TyoEzCgOR"
CONSUMER_SECRET      = "Q4zXS4rDFSk2ydOzQaFSjZD6Y6DbO03hKnTpVCzVUTrEY2aN9r"
ACCESS_TOKEN         = "9257722-gxuj2mQUEUPj7MH7cIQfOc92XVXcw95NduTbrIaz6k"
ACCESS_TOKEN_SECRET  = "AHrF5zKVUTMlqmkOz7ksO7KFhzJy13qNTPj0UA1gdnNWb"


ActiveRecord::Base.configurations = YAML.load_file('db/database.yml')
ActiveRecord::Base.establish_connection(:development)

module LineBot
  module TwitterStreaming
    class Middleman
      class TwitterFollow < ActiveRecord::Base
      end

      def initialize(options = {})
#        ActiveRecord::Base.configurations = YAML.load_file('db/database.yml')
#        ActiveRecord::Base.establish_connection(:development)
      end

      def run
        Parallel.each( TwitterFollow.all, in_threads: TwitterFollow.all.count ) do | tf |

          linebot = Line::Bot::Client.new do |config|
            config.channel_id = '1463167898'
            config.channel_secret = 'e7ac3a3a35dca5e0e456e02be4894e1b'
            config.channel_mid = 'u3eb7467cd18f1dbdaa2b51c07ccc19b6'
          end

          Twitter::Streaming::Client.new do |config|
             config.consumer_key        = CONSUMER_KEY
             config.consumer_secret     = CONSUMER_SECRET
             config.access_token        = ACCESS_TOKEN
             config.access_token_secret = ACCESS_TOKEN_SECRET

          end.filter( follow: tf.tid ) do | tweet |
            linebot.send_text(
              to_mid: tf.mid,
              text: "#{tweet.full_text}\n#{tweet.url}",
            ) if tweet.is_a?(Twitter::Tweet)
          end
          
        end
      end
    end
  end
end


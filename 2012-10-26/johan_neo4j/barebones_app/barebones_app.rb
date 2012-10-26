require 'bundler'
require 'bundler/setup'
require "barebones_app/version"
require 'neo4j-wrapper'
require 'sinatra'
require 'twitter'
require 'slim'
require "sinatra/reloader" if development?
require 'sinatra/resources'
require 'ruby-debug'

module BarebonesApp

end

# rails generate scaffold Tweet text:string link:string date:datetime tweet_id:string --indices tweet_id date text --has_n tags mentions links --has_one tweeted_by:tweeted
# rails generate scaffold User twid:string link:string --indices twid --has_n tweeted follows knows used_tags mentioned_from:mentions
# rails generate scaffold Link url:string --indices url --has_n tweets:links short_urls:redirected_link --has_one redirected_link
# rails generate scaffold Tag name:string --indices name --has_n tweets:tags used_by_users:used_tags


class Tweet
  include Neo4j::NodeMixin
  property :text, type: String, index: :fulltext
  property :link
  property :date, type: DateTime
  property :tweet_id
  index :tweet_id
  index :date
  index :text
  has_n :tags
  has_n :mentions
  has_n :links
  has_one(:tweeted_by).from(:tweeted)

  def to_s
    text.gsub(/(@\w+|https?\S+|#\w+)/,"").strip
  end

  def self.parse(item)
    {:tweet_id => item['id_str'],
     :text => item['text'],
     :date => Time.parse(item['created_at']),
     :link => "http://twitter.com/#{item['from_user']}/statuses/#{item['id_str']}"
    }
  end
end

class User
  include Neo4j::NodeMixin
  property :twid
  property :link
  index :twid
  has_n :tweeted
  has_n :follows
  has_n :knows
  has_n :used_tags
  has_n(:mentioned_from).from(:mentions)
end

class Link
  include Neo4j::NodeMixin
  property :url
  index :url
  has_n(:tweets).from(:links) 
  has_n(:short_urls).from(:redirected_link)
  has_one :redirected_link
end

class Tag
  include Neo4j::NodeMixin
  property :name
  index :name
  has_n(:tweets).from(:tags) 
  has_n(:used_by_users).from(:used_tags)

  rule :all
  # rule(:old) { age > 10 }
end

# get '/tags/setup' do
#   Neo4j::Transaction.run do
#     Tag.new(name: 'hej')
#     Tag.new(name: 'b')
#   end
# end

resource :tags do
  get do
    # show all posts
    @tags = Tag.all
    slim :tags
  end

  get :new do
    slim :new_tag
  end

  post do
    # create new post
    Neo4j::Transaction.run do
      tag = Tag.create(name: params[:name]) # #new is same as #create
      redirect to("tags/#{tag.neo_id}")
    end
    
  end

  member do
    get do
      # show post params[:id]
      debugger
      @tag = Tag.load_entity(params[:id].to_i)
      slim :show_tag
    end

    delete do
      # destroy post params[:id]
    end

    get :search do
      # show this post's comments
      @tag = Tag.find(params[:id])

      search = Twitter::Search.new
      result = search.hashtag(@tag.name)

      curr_page = 0
      while curr_page < 2 do
        result.each do |item|
          parsed_tweet_hash = Tweet.parse(item)
          next if Tweet.find_by_tweet_id(parsed_tweet_hash[:tweet_id])
          tweet = Tweet.create!(parsed_tweet_hash)

          twid = item['from_user'].downcase
          user = User.find_or_create_by(:twid => twid)
          user.tweeted << tweet
          user.save

          parse_tweet(tweet, user)
        end
        result.fetch_next_page
        curr_page += 1
      end

      redirect_to @tag
    end
  end
end



# post '/tags' do
# end


def parse_tweet(tweet, user)
  tweet.text.gsub(/(@\w+|https?:\/\/[a-zA-Z0-9\-\.~\:\?#\[\]\!\@\$&,\*+=;,\/]+|#\w+)/).each do |t|
    case t
      when /^@.+/
        t = t[1..-1].downcase
        next if t.nil?
        other = User.find_or_create_by(:twid => t)
        user.knows << other unless t == user.twid || user.knows.include?(other)
        user.save
        tweet.mentions << other
      when /#.+/
        t = t[1..-1].downcase
        tag = Tag.find_or_create_by(:name => t)
        tweet.tags << tag unless tweet.tags.include?(tag)
        user.used_tags << tag unless user.used_tags.include?(tag)
        user.save
      when /https?:.+/
        link = Link.find_or_create_by(:url => t)
        tweet.links << (link.redirected_link || link)
    end
  end
  tweet.save!
end



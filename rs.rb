require "json"
require "net/http"
require "openssl"
require "securerandom"

def user2lid(username)
  uri = URI("https://letterboxd.com/#{username}/")
  response = nil
  Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    response = http.head(uri)
  end
  lid = response['x-letterboxd-identifier']
end

def letterboxd(endpoint, user_params = "")
  apikey      = ENV.fetch("KEY")
  nonce       = SecureRandom.uuid
  timestamp   = Time.now.to_i
  base_url    = "https://api.letterboxd.com/api/v0"
  params      = "?apikey=#{apikey}&nonce=#{nonce}&timestamp=#{timestamp}#{user_params}"
  url         = "#{base_url}#{endpoint}#{params}"
  http_method = "GET"
  body        = ""
  digest      = OpenSSL::Digest::SHA256.new
  key         = ENV.fetch("SECRET")
  data        = "#{http_method}\u0000#{url}\u0000#{body}"
  signature   = OpenSSL::HMAC.hexdigest(digest, key, data)
  uri         = URI("#{url}&signature=#{signature}")
  response    = nil
  Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    response = http.get(uri)
  end
  JSON.parse(response.body)
rescue JSON::ParserError
  p response.body if response
  raise
end

def watchlist(username)
  lid = user2lid(username)
  names = []
  cursor = nil
  print "#{username}: "
  begin
    print "."
    endpoint = "/member/#{lid}/watchlist"
    params   = "&perPage=100"
    params  += "&cursor=#{cursor}" if cursor
    json     = letterboxd(endpoint, params)
    cursor   = json["next"]
    names   += json["items"].map { |item| item["name"] }
  end while cursor
  puts
  names
end

abort "No users given" if ARGV.empty?

users = {}

ARGV.each { |arg| users.store(arg, []) }

users.keys.each do |username|
  users[username] += watchlist(username)
end

common_movies = users.values.inject(:&)

require "pp"
pp common_movies

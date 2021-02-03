require 'net/http'
require 'colorize'
require 'json'
require 'uri'

class AutoRefreshingOAuthToken
  def request_new_token
    endpoint_uri = URI.parse('https://id.twitch.tv/oauth2/token')

    endpoint = Net::HTTP.new(endpoint_uri.host, endpoint_uri.port)
    endpoint.use_ssl = true

    request = Net::HTTP::Post.new(endpoint_uri.path)

    post_form_data = {
      'client_id' => @client_id,
      'client_secret' => @client_secret,
      'grant_type' => 'client_credentials'
    }

    request.set_form_data(post_form_data)
    endpoint.request(request)
  end

  def client_id
    @client_id
  end

  def get_token
    if @newest_token.nil? || @expiration.nil? || Time.now.to_i > @expiration
      response = request_new_token

      case response
      when Net::HTTPOK
        parsed_body = JSON.parse(response.body)
        @newest_token = parsed_body['access_token']
        @expiration = Time.now.to_i + parsed_body['expires_in']
      when Net::HTTPBadRequest
        puts 'Could not refresh the token, received an HTTP 400 bad request.'
        puts 'This is most likely due to an indvalid client id.'
      when Net::HTTPForbidden
        puts 'Could not refresh the token, received an HTTP 403 forbidden.'
        puts 'This is most likely due to an invalid client secret.'
      end
    end

    @newest_token
  end

  def initialize(client_id, client_secret)
    @client_id = client_id
    @client_secret = client_secret

    @newest_token = nil
    @expiration = nil
  end
end

def get_stream_info(login_names, oauth)
  endpoint_uri = URI.parse('https://api.twitch.tv/helix/streams')
  endpoint = Net::HTTP.new(endpoint_uri.host, endpoint_uri.port)
  endpoint.use_ssl = true

  url_arguments = nil

  if login_names.class == Array
    url_encoded_logins = ''

    login_names.each_with_index do |login_name, index| 
      url_encoded_logins += "#{index.zero? ? '?' : '&'}user_login=#{login_name}"
    end

    url_arguments = url_encoded_logins
  elsif login_names.class == String
    url_arguments = "?user_login=#{login_names}"
  end

  request = Net::HTTP::Get.new("#{endpoint_uri.path}#{url_arguments}")

  request['Authorization'] = "Bearer #{oauth.get_token}"
  request['client-id'] = oauth.client_id

  endpoint.request(request)
end

def render_api_response(streams_information, streamer_names)
  streams_information_map = streamer_names.map { |streamer_name| [streamer_name, nil] }.to_h

  streams_information['data'].each do |stream_data|
    streams_information_map[stream_data['user_name'].downcase] = stream_data
  end

  largest_streamer_username_length = streamer_names.max_by(&:length)
  minimum_pad_length = largest_streamer_username_length.size + 3

  system 'cls'

  streams_information_map.each do |streamer_name, stream_data|
    puts stream_data.nil? ? ('=' * 120).yellow : ('=' * 120).green
    print "#{stream_data.nil? ? streamer_name.red : streamer_name.green} #{(' ' * (minimum_pad_length - streamer_name.size))}"
    print stream_data.nil? ? ' | '.yellow : ' | '.green
    puts stream_data.nil? ? 'Offline'.red : ('Online'.green + ' for '.white + "#{stream_data['viewer_count']}".cyan + ' > '.white + "#{stream_data['title']}" + ' since '.white + "#{stream_data['started_at']}".cyan)
  end

  puts ('=' * 120).yellow
end

config_file = './config.json'

config_create_config = false

config_client_id = nil
config_client_secret = nil
config_streamer_names = nil
config_loop_mode = nil

config_helptext_mode = nil

ARGV.each_with_index do |argument, index|
  next_argument = (index + 1) < ARGV.size ? ARGV[index + 1] : nil

  config_helptext_mode = true if ['--help', '-h'].include?(argument)
  config_loop_mode = true if ['--loop', '-l'].include?(argument)
  config_create_config = true if ['--new-config-file', "-ncf"].include?(argument)
  
  next if next_argument.nil?

  config_file = next_argument if ['--config-file', '-cf'].include?(argument) && File.exist?(next_argument)
  config_client_id = next_argument if ['--client-id', '-cid'].include?(argument)
  config_client_secret = next_argument if ['--client-secret', '-cs'].include(argument)
  config_streamer_names = next_argument.split(';') if ['--streamers', '-s'].include?(argument)
end

if config_helptext_mode
  puts <<-eos
--help (-h)                  |   This help message.. Shouldn't need an explanation.
--loop (-l)                  |   Don't exit, keep refreshing livestreams every 15 seconds.

--new-config-file (-ncf)     |   Generate a new configuration file template rather than loading from it
                                 ('config.json' default, use -cf to change config path)

--config-file (-cf)          |   Specifies the config file path containing default settings (default 'config.json')
                                 If -ncf is specified, this is the path that will be used for the new config.

--client-id (-cid)           |   Required argument -- your Twitch API client ID.
--client-secret (-cs)        |   Required argument -- your Twitch API client secret.

--streamers (-s)             |   A list of streamer logon names to monitor separated by semicolons ';' e.g. --streamers streamer1;streamer2;streamer3 etc..
                                 Ideally this should be stored in the config file.
   eos

  exit
end

if File.exist?(config_file)
  begin
    config_map = JSON.parse open(config_file, 'r', &:read)

    config_client_id = config_map['client_id'] if config_client_id.nil?
    config_client_secret = config_map['client_secret'] if config_client_secret.nil?
    config_streamer_names = config_map['streamers'] if config_streamer_names.nil?
    config_loop_mode = config_map['loop_mode'] if config_loop_mode.nil?
  rescue JSON::JSONError => json_exception
    puts "JSON Exception when attempting to parse config file '#{config_file}', are you sure it's correctly formatted?"
    puts "#{json_exception.class}:#{json_exception}"
    exit
  end
elsif config_create_config
  config_file_template = {
    'client_id' => '',
    'client_secret' => '',
    'loop_mode' => true,
    'streamers' => []
  }

  begin
    File.open(config_file, 'w+') do |stream|
      stream.write JSON.dump(config_file_template)
    end
  rescue IOError => io_exception
    puts "Failed to write JSON config template to file '#{config_file}', are you sure the path is valid?"
    puts "#{io_exception.class}:#{io_exception}"
    exit
  end

  puts "Config file has been generated @ '#{config_file}', please fill it in."
  exit
else
  config_streamer_names = [] if config_streamer_names.nil?
  config_loop_mode = false if config_loop_mode.nil?

  if [config_client_id, config_client_secret].any?(&:nil?)
    puts "A valid client id and client secret is needed to communicate with Twitch's API."
    puts "Client ID Specified: #{!config_client_id.nil?}"
    puts "Client Secret Specified: #{!config_client_secret.nil?}"

    exit
  end
end

oauth_token = AutoRefreshingOAuthToken.new(config_client_id, config_client_secret)

if config_loop_mode
  loop do
    begin
      api_response_json = JSON.parse(get_stream_info(config_streamer_names, oauth_token).body)
      render_api_response(api_response_json, config_streamer_names)
    rescue => exception
      puts "Caught and ignoring exception: #{exception}"
    ensure
      sleep 15
    end
  end
else
  api_response_json = JSON.parse(get_stream_info(config_streamer_names, oauth_token).body)
  render_api_response(api_response_json, config_streamer_names)
end

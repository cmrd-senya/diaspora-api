#!/usr/bin/ruby
# encoding: utf-8

#
#    Copyright 2014-2016 cmrd Senya (senya@riseup.net)
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

require "net/http"
require "net/https"
require "uri"
require "json"
require "logger"

module DiasporaApi
end

class DiasporaApi::Client
  attr_writer :providername, :verify_mode, :proxy_host, :proxy_port

	def log_level=(level)
		@logger.level = level
	end

  def pod_host
    URI.parse(@poduri).host
  end

  def pod_scheme
    URI.parse(@poduri).scheme
  end

  def initialize(poduri)
    @poduri = poduri
		@providername = "d*-rubygem"
		@logger = Logger.new(STDOUT)
    @logger.datetime_format = "%H:%M:%S"
		@logger.level = Logger::INFO
    @logger.debug("diaspora_api client initialized")
	end

  def self.create_appropriate(poduri)
    version = self.new(poduri).supported_api_version
    if version.nil?
      InternalApi.new(poduri)
    else
      Object.const_get("ApiV#{version}").new(poduri)
    end
  end

  def supported_api_version
    nil
  end

  def parsed_nodeinfo
    @parsed_nodeinfo ||= query_nodeinfo
  end

  def nodeinfo_href
    if @nodeinfo_href.nil?
      begin
        response = send_plain_request(Net::HTTP::Get.new("/.well-known/nodeinfo"))
        if response.code == "200"
          @nodeinfo_href = JSON.parse(response.body)["links"]
            .select {|res| res["rel"] == "http://nodeinfo.diaspora.software/ns/schema/1.0"}
            .first["href"]
        end
      rescue Net::OpenTimeout
      rescue SocketError
      rescue Errno::EHOSTUNREACH
      end
    end

    @nodeinfo_href
  end

  def login(username, password)
    return nil if query_page_and_fetch_csrf("/users/sign_in").nil?

    response = sign_in_request(username, password)
    @logger.debug("resp: " + response.code)

    if response.code.to_i >= 400
      @logger.error("Login failed. Server replied with code " + response.code)
      return false
    else
      @logger.debug(response.response['set-cookie'])
      if not response.response['set-cookie'].include? "remember_user_token"
        @logger.debug("Login failed. Wrong password?")
        return false
      end
      @cookie = /remember_user_token=[[[:alnum:]]%-]+; /.match(response.response['set-cookie'])
      return true
    end
  end

  protected

  attr_reader :logger

  def send_request(request)
    request['Cookie']="#{@_diaspora_session}${@cookie}"
    response = send_plain_request(request)
    @_diaspora_session = /_diaspora_session=[[[:alnum:]]%-]+; /.match(response.response['set-cookie']).to_s
    @logger.debug("send_request: response code == #{response.code}")
    @logger.debug("location: #{response.header['location']}") unless response.header["location"].nil?
    response
  end

  def send_plain_request(request)
    uri = URI.parse(@poduri)
    @logger.debug("poduri #{@poduri} uri.host #{uri.host} uri.port #{uri.port}")

    http = Net::HTTP.new(uri.host, uri.port, @proxy_host, @proxy_port)
    http.use_ssl = uri.scheme == "https"
    http.verify_mode = @verify_mode unless @verify_mode.nil?
    http.request(request)
	end

  def fetch_csrf(response)
    atok_tag = /<meta[ a-zA-Z0-9=\/+"]+name=\"csrf-token\"[ a-zA-Z0-9=\/+"]+\/>/.match(response.body)[0]
    @logger.debug("atok_tag:\n#{atok_tag}")
    @atok = /content="([a-zA-Z0-9=\/\\+]+)"/.match(atok_tag)[1]
    @logger.debug("atok:\n#{@atok}")
    @atok
  end

  def query_page_and_fetch_csrf(path)
    request = Net::HTTP::Get.new(path)
    response = send_request(request)

    if response.code == "302"
      query_page_and_fetch_csrf(URI.parse(response.header['location']))
    elsif response.code != "200"
      @logger.error("Server returned error " + response.code)
      @logger.debug(response.to_s)
      nil
    else
      fetch_csrf(response)
      response
    end
  end

  def sign_in_request(username, password)
    request = Net::HTTP::Post.new("/users/sign_in")
    request.set_form_data('utf8' => '✓', 'user[username]' => username, 'user[password]' => password, 'user[remember_me]' => 1, 'commit' => 'Signin', 'authenticity_token' => @atok)
    send_request(request)
  end

  private

  def query_nodeinfo
    JSON.parse(Net::HTTP.get_response(URI.parse(nodeinfo_href)).body) unless nodeinfo_href.nil?
  end
end

require "diaspora_api/internal_api"
require "diaspora_api/api_v1"

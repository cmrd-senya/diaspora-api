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
  attr_writer :providername, :verify_mode, :proxy_host, :proxy_port, :use_ssl

	def log_level=(level)
		@logger.level = level
	end

  def pod_host
    URI.parse(@poduri).host
  end

  def initialize(poduri=nil, ssl=true)
    @poduri = poduri
    @use_ssl = ssl
		@providername = "d*-rubygem"
		@logger = Logger.new(STDOUT)
		@logger.datetime_format = "%H:%H:%S"
		@logger.level = Logger::INFO
		@logger.info("diaspora-api gem initialized")
	end

	def send_request(request)
		request['Cookie']="#{@_diaspora_session}${@cookie}"
		uri = URI.parse(@poduri)
    @logger.debug("poduri #{@poduri} uri.host #{uri.host} uri.port #{uri.port}")

		response = nil
		http = Net::HTTP.new(uri.host, uri.port,@proxy_host,@proxy_port)
    http.use_ssl = @use_ssl
		if(@verify_mode != nil)
			http.verify_mode = @verify_mode
		end
		response = http.request(request)

		@_diaspora_session = /_diaspora_session=[[[:alnum:]]%-]+; /.match(response.response['set-cookie']).to_s
		return response
	end

	def fetch_csrf(response)
		atok_tag = /<meta[ a-zA-Z0-9=\/+"]+name=\"csrf-token\"[ a-zA-Z0-9=\/+"]+\/>/.match(response.body)[0]
		@logger.debug("atok_tag:\n#{atok_tag}")
		@atok = /content="([a-zA-Z0-9=\/\\+]+)"/.match(atok_tag)[1]
		@logger.debug("atok:\n#{@atok}")
    @atok
	end

  def login(poduri, username, password)
    @poduri = poduri unless poduri.nil?

    return nil if query_page_and_fetch_csrf("/users/sign_in").nil?

		request = Net::HTTP::Post.new("/users/sign_in")
		request.set_form_data('utf8' => '✓', 'user[username]' => username, 'user[password]' => password, 'user[remember_me]' => 1, 'commit' => 'Signin', 'authenticity_token' => @atok)
		response = send_request(request)
		@logger.debug("resp: " + response.code)

		if response.code.to_i >= 400
			@logger.error("Login failed. Server replied with code " + response.code)
			return false
		else
			@logger.debug(response.response['set-cookie'])
			if not response.response['set-cookie'].include? "remember_user_token"
				@logger.error("Login failed. Wrong password?")
				return false
			end
			@cookie = /remember_user_token=[[[:alnum:]]%-]+; /.match(response.response['set-cookie'])
			return true
		end
	end

	def post(msg, aspect)
		if(aspect != "public")
      @logger.debug(aspects)
      aspect = get_aspect_id_by_name(aspect).to_s
		end

    return api_post(
      "/status_messages",
      {
        status_message: {
          text: msg,
          provider_display_name: @providername
        },
        aspect_ids: aspect
      }
    )
	end

  def get_aspect_id_by_name(name)
    aspects.select { |asp| asp["name"] == name }.first["id"]
  end

  def aspects
    attributes["aspects"]
  end

  def attributes
    @attributes || get_attributes
  end

	def get_attributes
	  response = query_page_and_fetch_csrf("/stream")
    return if response.nil?

		names = ["gon.user", "window.current_user_attributes"]
		i = nil

		for name in names
			i = response.body.index(name)
			break if i != nil
		end

		if i == nil
			@logger.error("Unexpected format")
      nil
		else
			start_json = response.body.index("{", i)
			i = start_json
			n = 0
			begin
				case response.body[i]
					when "{" then n += 1
					when "}" then n -= 1
				end
				i += 1
			end until n == 0
			end_json = i - 1

			@attributes = JSON.parse(response.body[start_json..end_json])
		end
	end

  def get_contacts
    request = Net::HTTP::Get.new("/contacts.json")
    response = send_request(request)

    return response.body if response.code == "200" || response.code == "202"
    return nil
  end

  # this method doesn't support captcha yet
  def register(email, username, password)
    return if query_page_and_fetch_csrf("/users/sign_up").nil?
    request = Net::HTTP::Post.new("/users")
    request.set_form_data("utf8" => "✓", "user[email]" => email, "user[username]" => username, "user[password]" => password, "user[password_confirmation]" => password, "commit" => "Sign up", "authenticity_token" => @atok)
    send_request(request)
  end

  def retrieve_remote_person(diaspora_id)
    send_request(
      Net::HTTP::Post.new("/people/by_handle").tap do |request|
        request.set_form_data(diaspora_handle: diaspora_id, authenticity_token: @atok)
      end
    )
  end

  def sign_out
    @attributes = nil
    send_request(
      Net::HTTP::Delete.new("/users/sign_out").tap do |request|
        request.set_form_data("authenticity_token" => @atok)
      end
    )
  end

  def search_people(query)
    send_request(Net::HTTP::Get.new("/people?q=#{query}", initheader = default_header))
  end

  def add_to_aspect(person_id, aspect_id)
    send_request(
      Net::HTTP::Post.new("/aspect_memberships", initheader = default_header).tap do |request|
        request.set_form_data(
          person_id: person_id,
          aspect_id: aspect_id,
          aspect_membership: {aspect_id: aspect_id}
        )
      end
    )
  end

  private

  def default_header
    {"Content-Type" =>"application/json", "accept" => "application/json", "x-csrf-token" => @atok}
  end

  def api_post(path, body)
    send_request(
      Net::HTTP::Post.new(path, initheader = default_header).tap { |request|
        request.body = body.to_json
      }
    )
  end

  def query_page_and_fetch_csrf(path)
    request = Net::HTTP::Get.new(path)
    response = send_request(request)

    unless response.code == "200"
      @logger.error("Server returned error " + response.code)
      nil
    else
      fetch_csrf(response)
      response
    end
  end
end

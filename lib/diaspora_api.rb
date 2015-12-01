#!/usr/bin/ruby
# encoding: utf-8

#
#    Copyright 2014 cmrd Senya (senya@riseup.net)
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

	@attributes
	@podhost
	@cookie
	@atok
	@_diaspora_session
	@logger

	def log_level=(level)
		@logger.level = level
	end

	def initialize
		@providername = "d*-rubygem"
		@cookie = nil
		@_diaspora_session = nil
		@proxy_host = nil
		@proxy_port = nil
		@verify_mode = nil
		@logger = Logger.new(STDOUT)
		@logger.datetime_format = "%H:%H:%S"
		@logger.level = Logger::INFO
		@logger.info("diaspora-api gem initialized")
	end

	def send_request(request)
		request['Cookie']="#{@_diaspora_session}${@cookie}"
		uri = URI.parse(@podhost)

		response = nil
		http = Net::HTTP.new(uri.host, uri.port,@proxy_host,@proxy_port)
		http.use_ssl = true
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
	end

	def login(podhost, username, password)
		@podhost = podhost

		request = Net::HTTP::Get.new("/users/sign_in")
		response = send_request(request)

		if response.code != "200"
			@logger.error("Server returned error " + response.code)
		end

		fetch_csrf(response)

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
			get_attributes
			return true
		end
	end

	def post(msg, aspect)
		@logger.debug(@attributes["aspects"])
		if(aspect != "public")
			for asp in @attributes["aspects"]
				if(aspect == asp["name"])
					aspect = asp["id"].to_s
				end
			end
		end

		request = Net::HTTP::Post.new("/status_messages",initheader = {'Content-Type' =>'application/json','accept' => 'application/json', 'x-csrf-token' => @atok})
		request.body = { "status_message" => { "text" => msg, "provider_display_name" => @providername }, "aspect_ids" => aspect}.to_json
		return send_request(request)
	end

	def get_attributes
		request = Net::HTTP::Get.new("/stream")
		response = send_request(request)
		fetch_csrf(response)

		names = ["gon.user", "window.current_user_attributes"]
		i = nil

		for name in names
			i = response.body.index(name)
			break if i != nil
		end


		if i == nil
			@logger.error("Unexpected format")
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
end

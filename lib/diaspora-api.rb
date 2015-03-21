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

class DiasporaApi
end

class DiasporaApi::Client
	@providername
	@attributes
	@podhost
	@cookie
	
	def initialize
		@providername = "d*-rubygem"
		@cookie = nil		
	end

	def login(podhost, username, password)
		@podhost = podhost
		uri = URI.parse(podhost + "/users/sign_in")
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true

		request = Net::HTTP::Get.new(uri.request_uri)

		response = http.request(request)
		if response.code != "200"
			puts "Server returned error " + response.code
		end

		scookie = /_diaspora_session=[[[:alnum:]]%-]+; /.match(response.response['set-cookie'])
		atok = /\<input name="authenticity_token" type="hidden" value="([[[:alnum:]][[:punct:]]]+)" \/\>/.match(response.body)[1]

		request = Net::HTTP::Post.new(uri.request_uri)
		request.set_form_data('utf8' => '✓', 'user[username]' => username, 'user[password]' => password, 'user[remember_me]' => 1, 'commit' => 'Signin', 'authenticity_token' => atok)
		request['Cookie'] = scookie

		response = http.request(request)

		if response.code.to_i >= 400
			puts "Login failed. Server replied with code " + response.code
			return false
		else
			if not response.response['set-cookie'].include? "remember_user_token"
				puts "Login failed. Wrong password?"
				return false
			end
			@cookie = /remember_user_token=[[[:alnum:]]%-]+; /.match(response.response['set-cookie'])
			get_attributes
			return true
		end
	end
	
	def post(msg, aspect)
		if(aspect != "public")
			for asp in @attributes["aspects"]
				if(aspect == asp["name"])
					aspect = asp["id"].to_s
				end
			end
		end
	
		uri = URI.parse(@podhost + "/status_messages")
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		
		request = Net::HTTP::Post.new(uri.request_uri,initheader = {'Content-Type' =>'application/json'})
		request['Cookie'] = @cookie

		request.body = { "status_message" => { "text" => msg, "provider_display_name" => @providername }, "aspect_ids" => aspect}.to_json

		return http.request(request)
	end
	
	def get_attributes
		uri = URI.parse(@podhost + "/stream")
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		
		request = Net::HTTP::Get.new(uri.request_uri)
		request['Cookie'] = @cookie

		response = http.request(request)
		names = ["gon.user", "window.current_user_attributes"]
		i = nil
		
		for name in names
			i = response.body.index(name)
			break if i != nil
		end


		if i == nil
			puts "Unexpected format"
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















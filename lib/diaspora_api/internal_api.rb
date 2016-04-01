class DiasporaApi::InternalApi < DiasporaApi::Client
  def current_version
    nil
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
    ).code == "201"
  end

  def stream
    default_json_get_query("/stream")
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
    default_json_get_query("/contacts")
  end

  # this method doesn't support captcha yet
  def register(email, username, password)
    return if query_page_and_fetch_csrf("/users/sign_up").nil?
    request = Net::HTTP::Post.new("/users")
    request.set_form_data("utf8" => "✓", "user[email]" => email, "user[username]" => username, "user[password]" => password, "user[password_confirmation]" => password, "commit" => "Sign up", "authenticity_token" => @atok)
    send_request(request).code == "302"
  end

  def retrieve_remote_person(diaspora_id)
    send_request(
      Net::HTTP::Post.new("/people/by_handle").tap do |request|
        request.set_form_data(diaspora_handle: diaspora_id, authenticity_token: @atok)
      end
    )
  end

  def find_or_fetch_person(diaspora_id, attempts = 10)
    people = search_people(diaspora_id)
    if people.count == 0
      retrieve_remote_person(diaspora_id)
      attempts.times do
        sleep(1)
        people = search_people(diaspora_id)
        break if people.count > 0
      end
    end

    people
  end

  def sign_out
    resp = send_request(
      Net::HTTP::Delete.new("/users/sign_out").tap do |request|
        request.set_form_data("authenticity_token" => @atok)
      end
    )
    self.freeze
    resp
  end

  def search_people(query)
    default_json_get_query("/people?q=#{query}")
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
    ).code == "200"
  end

  def notifications
    default_json_get_query("/notifications")
  end

  private

  def default_json_get_query(path)
    resp = send_request(Net::HTTP::Get.new(path, initheader = default_header))
    if resp.code == "200" || resp.code == "202"
      JSON.parse(resp.body)
    else
      nil
    end
  end

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
end

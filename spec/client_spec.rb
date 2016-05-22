require "spec_helper"

describe DiasporaApi::InternalApi do
  def client
    @client ||= DiasporaApi::InternalApi.new(test_pod_host)
  end

  before do
    client.log_level = Logger::DEBUG
  end

  describe "#registration" do
    it "returns 302 on correct query" do
      expect(client.register("test#{r_str}@test.local", "test#{r_str}", "123456")).to be_truthy
    end
  end

  context "using preloaded fixtures" do
    before do
      expect(client.login("alice", "bluepin7")).to be_truthy
    end

    describe "#get_contacts" do
      it "replies on contacts query" do
        expect(client.get_contacts).not_to be_nil
      end

      it "replies on contacts query after failed retrieve query" do
        client.retrieve_remote_person("idontexist@example.com")
        expect(client.get_contacts).not_to be_nil
      end
    end
  end

  context "require registration" do
    before do
      @username = "test#{r_str}"
      expect(client.register("test#{r_str}@test.local", @username, "123456")).to be_truthy
    end

    describe "#retrieve_remote_person" do
      it "returns 200" do
        expect(client.retrieve_remote_person("hq@pod.diaspora.software").response.code).to eq("200")
      end
    end

    describe "#find_or_fetch_person" do
      it "returns correct response" do
        people = client.find_or_fetch_person("hq@pod.diaspora.software")
        expect(people).not_to be_nil
        expect(people.count).to be > 0
      end
    end

    it "replies on contacts query" do
      expect(client.get_contacts).not_to be_nil
    end

    describe "#get_attributes" do
      it "returns aspect list" do
        expect(client.aspects.count).to be > 0
      end
    end

    describe "#sign_out" do
      it "returns 204 on correct sign out" do
        expect(client.sign_out.code).to eq("204")
      end
    end

    describe "#delete_account" do
      it "with correct parameters works" do
        expect(client.delete_account("123456")).to be_truthy
      end
    end

    describe "#change_username" do
      it "works with correct parameters" do
        new_name = "ivan#{r_str}"
        expect(client.change_username(new_name, "123456")).to be_truthy
        sleep(2)
        expect(DiasporaApi::InternalApi.new(test_pod_host).login(new_name, "123456")).to be_truthy
      end
    end

    context "with second user" do
      before do
        @client = nil
        @username2 = "test#{r_str}"
        expect(client.register("test#{r_str}@test.local", @username2, "123456")).to be_truthy
      end

      it "adds the other user to an aspect" do
        people = client.search_people(@username)
        expect(people.count).to be > 0
        result = client.add_to_aspect(people.first["id"], client.aspects.first["id"])
        expect(result).to be_truthy
      end
    end
  end
end

require "spec_helper"

describe DiasporaApi::Client do
  before do
    @client = DiasporaApi::Client.new(test_pod_host, false)
    @client.log_level = Logger::DEBUG
  end

  describe "#registration" do
    it "returns 302 on correct query" do
      response = @client.register("test#{r_str}@test.local", "test#{r_str}", "123456")
      expect(response.code).to eq("302")
    end
  end

  context "require registration" do
    before do
      @username = "test#{r_str}"
      response = @client.register("test#{r_str}@test.local", @username, "123456")
      expect(response.code).to eq("302")
    end

    describe "#retrieve_remote_person" do
      it "returns 200" do
        expect(@client.retrieve_remote_person("hq@pod.diaspora.software").response.code).to eq("200")
      end
    end

    describe "#search_people" do
      it "returns correct response" do
        response = @client.search_people("hq@pod.diaspora.software").response
        expect(response.code).to eq("200")
      end
    end

    describe "#get_attributes" do
      it "returns aspect list" do
        expect(@client.aspects.count).to be > 0
      end
    end

    context "with second user" do
      before do
        expect(@client.sign_out.code).to eq("204")
        @username2 = "test#{r_str}"
        response = @client.register("test#{r_str}@test.local", @username2, "123456")
        expect(response.code).to eq("302")
      end

      it "adds the other user to an aspect" do
        people = JSON.parse(@client.search_people(@username).body)
        expect(people.count).to be > 0
        response = @client.add_to_aspect(people.first["id"], @client.aspects.first["id"])
        expect(response.code).to eq("200")
      end
    end
  end
end

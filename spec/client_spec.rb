require "spec_helper"

describe DiasporaApi::InternalApi do
  def client
    @client ||= DiasporaApi::InternalApi.new(test_pod_host)
  end

  def drop_client
    @client = nil
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

    describe "#post" do
      it "returns correctly with correct input" do
        result, data = client.post("message!!!", "public")
        expect(result).to be_truthy
        expect(data).to have_key("guid")
        expect(data["post_type"]).to eq("StatusMessage")
      end
    end

    context "with a post" do
      let(:post_data) { client.post("message!!!", "public") }

      before do
        expect(post_data[0]).to be_truthy
        expect(post_data[1]).to have_key("id")
      end

      describe "#comment" do
        it "returns correctly with correct input" do
          result, data = client.comment("comment text", post_data[1]["id"])
          expect(result).to be_truthy
        end
      end

      describe "#retract_post" do
        it "returns truthy value on correct input" do
          expect(client.retract_post(post_data[1]["id"])).to be_truthy
        end
      end

      context "with a comment" do
        let(:comment_data) { client.comment("message!!!", post_data[1]["id"]) }

        describe "#retract_comment" do
          it "returns truthy value on correct input" do
            expect(client.retract_comment(comment_data[1]["id"])).to be_truthy
          end
        end
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
      xit "works with correct parameters" do
        new_name = "ivan#{r_str}"
        expect(client.change_username(new_name, "123456")).to be_truthy
        sleep(2)
        expect(DiasporaApi::InternalApi.new(test_pod_host).login(new_name, "123456")).to be_truthy
      end
    end

    context "with second user" do
      before do
        drop_client
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

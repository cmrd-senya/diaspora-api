require "spec_helper"

describe DiasporaApi::Client do
  describe "nodeinfo" do
    it "returns href for the nodeinfo document" do
      expect(DiasporaApi::Client.new(test_pod_host).nodeinfo_href).not_to be_nil
    end

    it "returns nil for the wrong pod URI" do
      expect(DiasporaApi::Client.new("http://example.com").nodeinfo_href).to be_nil
    end

    it "returns nil for the non-existent URI" do
      expect(DiasporaApi::Client.new("http://example#{r_str}.local").nodeinfo_href).to be_nil
    end
  end
end

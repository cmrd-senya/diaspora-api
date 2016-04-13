require "rspec/core/rake_task"
$LOAD_PATH.push("#{File.dirname(__FILE__)}/lib")
require "#{File.dirname(__FILE__)}/diaspora-replica/api"

include Diaspora::Replica::API

self.logdir = "#{File.dirname(__FILE__)}/log"

RSpec::Core::RakeTask.new(:spec)

task :default => :execute_tests

task :bring_up_testenv do
  if machine_off?("development")
    report_info "Bringing up test environment"
    within_diaspora_replica { pipesh "vagrant up development" }
  end
end

task :deploy_app => :bring_up_testenv do
  deploy_app("development")
end

%w(start stop).each do |cmd|
  task "#{cmd}_pod" do
    if machine_off?("development")
      logger.info "Required machines are halted! Aborting"
    else
      eye(cmd, "development")
      wait_pod_up("http://development.diaspora.local", timeout=60)
    end
  end
end

task :execute_tests => %i(bring_up_testenv stop_pod deploy_app start_pod spec)

task :clean do
  within_diaspora_replica { system "vagrant destroy development" }
end

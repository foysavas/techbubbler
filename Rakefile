require 'rake'
require './app'

desc "irb console"
task :console do
  require 'irb'
  ARGV.clear
  IRB.start
end

desc "development server"
task :dev do
  Thread.new do
    `redis-server config/dev/redis.conf`
  end
  IO.popen("bundle exec unicorn") do |pipe|
    pipe.each do |line|
      STDOUT.puts line
    end
  end
end

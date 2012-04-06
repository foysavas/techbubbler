set :application, "techbubbler"
set :repository,  "git://github.com/foysavas/techbubbler.git"

set :scm, :git
set :branch, "master"
set :deploy_to, "/data/techbubbler"

role :app, "techbubbler.com"
set :user, "root"

namespace :deploy do
  task :start do ; end
  task :end do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "mkdir -p #{deploy_to}/current/config/prod"
    run "ln -s #{deploy_to}/shared/config/redis.conf #{deploy_to}/current/config/prod"
    run "ln -s #{deploy_to}/shared/config/twitter.rb #{deploy_to}/current/config"
    run "rm -rf #{deploy_to}/current/tmp; ln -s #{deploy_to}/shared/tmp #{deploy_to}/current/tmp"
    run "god restart #{application}"
  end
end

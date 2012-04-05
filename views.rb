get '/' do
    @title = "Top News - #{SiteName}"
    @news, @numitems = get_top_news
    haml :top, :layout => :page
end

get '/latest' do
    redirect '/latest/0'
end

get '/latest/:start' do
    @title = "Latest news - #{SiteName}"
    start = params[:start].to_i
    @paginate = {
        :get => Proc.new {|start,count|
            get_latest_news(start,count)
        },
        :render => Proc.new {|item| haml(:news_item, :locals => {:news => item})},
        :start => start,
        :perpage => LatestNewsPerPage,
        :link => "/latest/$"
    }
    haml :latest, :layout => :page
end

get '/saved/:start' do
    redirect "/login" if !$user
    start = params[:start].to_i
    @title = "Saved news - #{SiteName}"
    @paginate = {
        :get => Proc.new {|start,count|
            get_saved_news($user['id'],start,count)
        },
        :render => Proc.new {|item| haml(:news_item, :locals => {:news => item})},
        :start => start,
        :perpage => SavedNewsPerPage,
        :link => "/saved/$"
    }
    haml :saved, :layout => :page
end

get '/usercomments/:username/:start' do
    start = params[:start].to_i
    @user = get_user_by_username(params[:username])
    halt(404,"Non existing user") if !@user

    @title = "#{H.entities @user['username']} comments - #{SiteName}"
    @paginate = {
        :get => Proc.new {|start,count|
            get_user_comments(@user['id'],start,count)
        },
        :render => Proc.new {|comment|
            u = get_user_by_id(comment["user_id"]) || DeletedUser
            haml :comment_html, :locals => {:c => comment, :u => u}
        },
        :start => start,
        :perpage => UserCommentsPerPage,
        :link => "/usercomments/#{H.urlencode @user['username']}/$"
    }
    haml :usercomments, :layout => :page
end

get '/replies' do
    redirect "/login" if !$user
    @comments,@count = get_user_comments($user['id'],0,SubthreadsInRepliesPage)
    @title = "Your threads - #{SiteName}"
    haml :replies, :layout => :page
end

get '/login' do
  @on_login = true
    @title = "Login - #{SiteName}"
    haml :login, :layout => :page
end

get '/signup' do
  @on_signup = true
    @title = "signup - #{SiteName}"
    haml :signup, :layout => :page
end


get '/submit' do
  @on_submit = true
    redirect "/auth/twitter" if !$user
    @title = "Submit a new story - #{SiteName}"
    haml :submit, :layout => :page
end

get '/logout' do
    if $user and check_api_secret
      puts 'user: ', $user.inspect
      update_auth_token($user["id"])
    end
    redirect "/"
end

get "/news/:news_id" do
    @news = get_news_by_id(params["news_id"])
    halt(404,"404 - This news does not exist.") if !@news
    # Show the news text if it is a news without URL.
    if !news_domain(@news)
        c = {
            "body" => news_text(@news),
            "ctime" => @news["ctime"],
            "user_id" => @news["user_id"],
            "thread_id" => @news["id"],
            "topcomment" => true
        }
        user = get_user_by_id(@news["user_id"]) || DeletedUser
        @top_comment = H.topcomment { haml :comment_html, :locals => {:c => c,:u => user} }
    else
        @top_comment = ""
    end
    @title = "#{H.entities @news["title"]} - #{SiteName}"
    haml :news, :layout => :page
end

get "/comment/:news_id/:comment_id" do
    @news = get_news_by_id(params["news_id"])
    halt(404,"404 - This news does not exist.") if !@news
    @comment = Comments.fetch(params["news_id"],params["comment_id"])
    halt(404,"404 - This comment does not exist.") if !@comment
    haml :comment, :layout => :page
end

get "/reply/:news_id/:comment_id" do
    redirect "/login" if !$user
    @news = get_news_by_id(params["news_id"])
    halt(404,"404 - This news does not exist.") if !@news
    @comment = Comments.fetch(params["news_id"],params["comment_id"])
    halt(404,"404 - This comment does not exist.") if !@comment
    @user = get_user_by_id(@comment["user_id"]) || DeletedUser

    @title = "Reply to comment - #{SiteName}"
    haml :reply, :layout => :page
end

get "/editcomment/:news_id/:comment_id" do
    redirect "/login" if !$user
    @news = get_news_by_id(params["news_id"])
    halt(404,"404 - This news does not exist.") if !@news
    @comment = Comments.fetch(params["news_id"],params["comment_id"])
    halt(404,"404 - This comment does not exist.") if !@comment
    @user = get_user_by_id(@comment["user_id"]) || DeletedUser
    halt(500,"Permission denied.") if $user['id'].to_i != @user['id'].to_i

    @title = "Edit comment - #{SiteName}"
    haml :editcomment, :layout => :page
end

get "/editnews/:news_id" do
    redirect "/login" if !$user
    @news = get_news_by_id(params["news_id"])
    halt(404,"404 - This news does not exist.") if !@news
    halt(500,"Permission denied.") if $user['id'].to_i != @news['user_id'].to_i

    if news_domain(@news)
        @text = ""
    else
        @text = news_text(@news)
        @news['url'] = ""
    end
    @title = "Edit news - #{SiteName}"
    haml :editnews, :layout => :page
end

get "/user/:username" do
    @user = get_user_by_username(params[:username])
    halt(404,"Non existing user") if !@user
    @posted_news,@posted_comments = $r.pipelined {
      $r.zcard("user.posted:#{@user['id']}")
      $r.zcard("user.comments:#{@user['id']}")
    }
    @title = "#{H.entities @user['username']} - #{SiteName}"
    @owner = $user && ($user['id'].to_i == @user['id'].to_i)
    haml :user, :layout => :page
end


get '/rss' do
  content_type 'text/xml', :charset => 'utf-8'
  @news,@count = get_latest_news
  haml :rss
end

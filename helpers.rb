###############################################################################
# Utility functions
###############################################################################

# Given an unix time in the past returns a string stating how much time
# has elapsed from the specified time, in the form "2 hours ago".
def str_elapsed(t)
    seconds = Time.now.to_i - t
    return "now" if seconds <= 1
    return "#{seconds} seconds ago" if seconds < 60
    return "#{seconds/60} minutes ago" if seconds < 60*60
    return "#{seconds/60/60} hours ago" if seconds < 60*60*24
    return "#{seconds/60/60/24} days ago"
end

def gravatar_url_for(email="",s=48)
  digest = Digest::MD5.hexdigest(email)
  "http://gravatar.com/avatar/#{digest}?s=#{s}&d=mm"
end

###############################################################################
# Navigation, header and footer.
###############################################################################

# Return the HTML for the 'replies' link in the main navigation bar.
# The link is not shown at all if the user is not logged in, while
# it is shown with a badge showing the number of replies for logged in
# users.
def replies_link
    return "" if !$user
    count = $user['replies'] || 0
    H.a(:href => "/replies", :class => "replies") {
        "replies"+
        if count.to_i > 0
            H.sup {count}
        else "" end
    }
end

# Given a string returns the same string with all the urls converted into
# HTML links. We try to handle the case of an url that is followed by a period
# Like in "I suggest http://google.com." excluding the final dot from the link.
def urls_to_links(s)
    urls = /((https?:\/\/|www\.)([-\w\.]+)+(:\d+)?(\/([\w\/_\.\-\%]*(\?\S+)?)?)?)/
    s.gsub(urls) {
        if $1[-1..-1] == '.'
            url = $1.chop
            '<a href="'+url+'">'+url+'</a>.'
        else
            '<a href="'+$1+'">'+$1+'</a>'
        end
    }
end

def render_comments_for_news(news_id,root=-1)
    html = ""
    user = {}
    Comments.render_comments(news_id,root) {|c|
        user[c["id"]] = get_user_by_id(c["user_id"]) if !user[c["id"]]
        user[c["id"]] = DeletedUser if !user[c["id"]]
        u = user[c["id"]]
        html << haml(:comment_html, :locals => {:u => u, :c => c})
    }
    H.div("id" => "comments") {html}
end

# Show list of items with show-more style pagination.
#
# The function sole argument is an hash with the following fields:
#
# :get     A function accepinng start/count that will return two values:
#          1) A list of elements to paginate.
#          2) The total amount of items of this type.
#
# :render  A function that given an element obtained with :get will turn
#          in into a suitable representation (usually HTML).
#
# :start   The current start (probably obtained from URL).
#
# :perpage Number of items to show per page.
#
# :link    A string that is used to obtain the url of the [more] link
#          replacing '$' with the right value for the next page.
#
# Return value: the current page rendering.
def list_items(o)
    aux = ""
    o[:start] = 0 if o[:start] < 0
    items,count = o[:get].call(o[:start],o[:perpage])
    items.each{|n|
        aux << o[:render].call(n)
    }
    last_displayed = o[:start]+o[:perpage]
    if last_displayed < count
        nextpage = o[:link].sub("$",
                   (o[:start]+o[:perpage]).to_s)
        aux << H.a(:href => nextpage,:class=> "more") {"[more]"}
    end
    aux
end


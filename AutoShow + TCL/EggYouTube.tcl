###########################################################################################
#                      ____  ____  _     ____  _     ____ 	                          #
#                     /  _ \/ ___\/ \   /  __\/ \   / ___\	                          #
#                     | / \||    \| |   |  \/|| |   |    \	                          #
#                     | |-||\___ || |_/\|  __/| |_/\\___ |	                          #
#                     \_/ \|\____/\____/\_/   \____/\____/	                          #
#                       asl_pls / irc.underx.org #aslpls    	                          #
#                                                                                         #
########################################################################################### 
#
# EggYoutube.tcl - Eggdrop script
# Features: Generic Titles, Auto-Shortening, YouTube Videos/Live Stats, and YouTube Channel Info
#
########################################################################################### 


package require http
package require tls
package require json

::http::register https 443 [list ::tls::socket -autoservername 1]

# CONFIGURATION
# https://console.cloud.google.com/


set yt_apikey "YOUR-API-KEY-HERE"
set max_url_len 35


# Bind to public channel messages
bind pubm - * pub_urltitle

proc pub_urltitle {nick uhost hand chan text} {
    global yt_apikey max_url_len

    # 1. Match YouTube Channel Links (handles @handle or /c/ or /channel/)
    if {[regexp -nocase {youtube\.com/(?:c/|channel/|user/)?(@[^\s/?]+|[a-zA-Z0-9_-]+)} $text -> channel_handle]} {
        # If it's a video link, let the video block catch it instead
        if {![string match -nocase "*watch*" $text] && ![string match -nocase "*youtu.be*" $text]} {
            set api_url "https://www.googleapis.com/youtube/v3/channels?part=snippet,statistics&forHandle=$channel_handle&key=$yt_apikey"
            # Fallback if it's an old-style ID instead of a handle
            if {[string match "UC*" $channel_handle]} {
                set api_url "https://www.googleapis.com/youtube/v3/channels?part=snippet,statistics&id=$channel_handle&key=$yt_apikey"
            }
            ::http::geturl $api_url -command [list parse_youtube_channel $chan] -timeout 5000
            return
        }
    }

    # 2. Match YouTube Video Links
    if {[regexp -nocase {(?:youtube\.com/(?:[^\s/]+/\\S+/|(?:v|e(?:mbed)?)/|.*[?&]v=)|youtu\.be/)([^"&?/\s]{11})} $text -> videoid]} {
        set api_url "https://www.googleapis.com/youtube/v3/videos?part=snippet,statistics,contentDetails&id=$videoid&key=$yt_apikey"
        ::http::geturl $api_url -command [list parse_youtube_video $chan] -timeout 5000
        return
    }

    # 3. Match Generic HTTP/HTTPS links
    if {[regexp -nocase {(https?://[^\s]+)} $text url]} {
        if {[string length $url] > $max_url_len && ![string match -nocase "*is.gd*" $url] && ![string match -nocase "*youtu.be*" $url]} {
            set short_api "https://is.gd/create.php?format=simple&url=[::http::formatQuery $url]"
            ::http::geturl $short_api -command [list fetch_title_after_shorten $chan $url] -timeout 4000
        } else {
            ::http::geturl $url -command [list parse_generic_title $chan $url ""] -timeout 5000
        }
    }
}

proc fetch_title_after_shorten {chan original_url token} {
    set short_url ""
    if {[::http::status $token] eq "ok" && [::http::ncode $token] == 200} {
        set short_url [string trim [::http::data $token]]
    }
    ::http::cleanup $token
    ::http::geturl $original_url -command [list parse_generic_title $chan $original_url $short_url] -timeout 5000
}

# PARSE YOUTUBE CHANNEL LINKS
proc parse_youtube_channel {chan token} {
    if {[::http::status $token] ne "ok"} { ::http::cleanup $token; return }
    set data [::http::data $token]
    ::http::cleanup $token

    if {[catch {set json_data [::json::json2dict $data]} err]} { return }
    set items [dict get $json_data items]
    if {[llength $items] == 0} { return }

    set channel [lindex $items 0]
    set snippet [dict get $channel snippet]
    set stats [dict get $channel statistics]

    set ch_title [dict get $snippet title]
    set ch_desc [dict get $snippet description]
    
    # Trim description to fit neatly in an IRC line
    set ch_desc [string range [regsub -all {\s+} $ch_desc " "] 0 80]...

    set subs "Hidden"
    if {![dict get $stats hiddenSubscriberCount]} {
        set subs [format_num [dict get $stats subscriberCount]]
    }
    set videos [format_num [dict get $stats videoCount]]

    set b [color_bold]
    set c "\003"
    
    # Format: [YouTube Channel] CreatorName | Subs: 1.2M | Total Videos: 342 | "Bio..."
    set output "${c}04\[YouTube Channel\]${c} ${b}${ch_title}${b} | ${b}Subscribers:${b} $subs | ${b}Videos:${b} $videos | \"${ch_desc}\""
    
    putquick "PRIVMSG $chan :$output"
}

# PARSE YOUTUBE VIDEO LINKS
proc parse_youtube_video {chan token} {
    if {[::http::status $token] ne "ok"} { ::http::cleanup $token; return }
    set data [::http::data $token]
    ::http::cleanup $token

    if {[catch {set json_data [::json::json2dict $data]} err]} { return }
    set items [dict get $json_data items]
    if {[llength $items] == 0} { return }

    set video [lindex $items 0]
    set snippet [dict get $video snippet]
    set stats [dict get $video statistics]
    set details [dict get $video contentDetails]

    set title [dict get $snippet title]
    set channel [dict get $snippet channelTitle]
    set published [dict get $snippet publishedAt]
    regexp {^(\d{4})} $published -> pub_year

    set broadcast_status "none"
    if {[dict exists $snippet liveBroadcastContent]} {
        set broadcast_status [dict get $snippet liveBroadcastContent]
    }

    set b [color_bold]
    set c "\003"
    
    if {$broadcast_status eq "live"} {
        set viewers "N/A"; if {[dict exists $stats viewCount]} { set viewers [format_num [dict get $stats viewCount]] }
        set output "${c}04\[YouTube\]${c} ${c}04,01${b}\[LIVE NOW\]${b}${c} ${b}${title}${b} by ${b}${channel}${b} | ${b}Watching:${b} $viewers"
    } elseif {$broadcast_status eq "upcoming"} {
        set output "${c}04\[YouTube\]${c} ${c}10\[UPCOMING STREAM\]${c} ${b}${title}${b} by ${b}${channel}${b} (Scheduled for ${pub_year})"
    } else {
        set raw_duration [dict get $details duration]
        set duration [parse_iso_duration $raw_duration]
        set views "N/A"; if {[dict exists $stats viewCount]} { set views [format_num [dict get $stats viewCount]] }
        set likes "N/A"; if {[dict exists $stats likeCount]} { set likes [format_num [dict get $stats likeCount]] }

        set output "${c}04\[YouTube\]${c} ${b}${title}${b} by ${b}${channel}${b} (${pub_year}) | ${b}Length:${b} ${duration} | ${b}Views:${b} $views | ${b}Likes:${b} $likes"

    }
    
    putquick "PRIVMSG $chan :$output"
}

proc parse_iso_duration {dur} {
    set hours 0; set minutes 0; set seconds 0
    regexp -nocase {(\d+)H} $dur -> hours
    regexp -nocase {(\d+)M} $dur -> minutes
    regexp -nocase {(\d+)S} $dur -> seconds

    if {$hours > 0} {
        return [format "%d:%02d:%02d" $hours $minutes $seconds]
    } else {
        return [format "%d:%02d" $minutes $seconds]
    }
}

proc parse_generic_title {chan url short_url token} {
    if {[::http::status $token] ne "ok"} { ::http::cleanup $token; return }
    set data [::http::data $token]
    ::http::cleanup $token

    if {[regexp -nocase {<title>(.*?)</title>} $data -> title]} {
        set title [regsub -all {\s+} [string trim $title] " "]
        set title [string map {&quot; "\"" &amp; "&" &lt; "<" &gt; ">" &#39; "'"} $title]
        
        set b [color_bold]
        if {$short_url ne ""} {
            putquick "PRIVMSG $chan :${b}URL Title:${b} $title | ${b}Shorten:${b} $short_url"
        } else {
            putquick "PRIVMSG $chan :${b}URL Title:${b} $title"
        }
    }
}

proc format_num {num} {
    while {[regexp {^([-+]?\d+)(\d{3})} $num -> pref suff]} { set num "$pref,$suff" }
    return $num
}

proc color_bold {} { return "\002" }

putlog "Loaded successfully: EggYouTube.tcl"
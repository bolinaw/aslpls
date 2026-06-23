##############################################################
#	_______ ______________ ________ ______ ________
#	___    |__  ___/___  / ___  __ \___  / __  ___/
#	__  /| |_____ \ __  /  __  /_/ /__  /  _____ \ 
#	_  ___ |____/ / _  /____  ____/ _  /_______/ / 
#	/_/  |_|/____/  /_____//_/      /_____//____/  
#		    asl_pls / irc.underx.org	
#							
##############################################################
#
# 	EggNews.tcl by asl_pls 
#	Google News RSS with Custom Minute Timer & TinyURL Support
#
# 	Features:
#   	- !news <country_code> (e.g., !news US, !news GB, !news JP)
#   	- Automated updates at customizable minute intervals
#   	- Automatic TinyURL shortening for clean channel output
#   	- Custom timestamp layout: DD-MM-YYYY HH AM/PM
#
##############################################################

namespace eval ::GoogleNews {
    # --------------------------------------------------------------------------
    # CONFIGURATION
    # --------------------------------------------------------------------------
    variable channel     "#aslpls"    ;# Channel to announce automated news
    variable default_gl  "US"              ;# Default country code for automation
    variable default_hl  "en"              ;# Default language code for automation
    variable max_items   3                 ;# Number of headlines to display per run
    variable auto_timer  60                ;# Timer interval in MINUTES (e.g., 60 = 1 hour)

    # Bindings
    bind pub - !news [namespace current]::pub_news
    
    # Initialize Packages
    package require http
    package require tls
    ::http::register https 443 [list ::tls::socket -autoservername 1]

    # Initialize the dynamic loop upon loading the script
    variable loop_id ""
    if {$loop_id eq ""} {
        utimer 10 [namespace current]::auto_news_loop
    }

    # --------------------------------------------------------------------------
    # TINYURL SHORTENER HELPER
    # --------------------------------------------------------------------------
    proc shorten_url {long_url} {
        set api_url "http://tinyurl.com/api-create.php?[::http::formatQuery url $long_url]"
        if {[catch {::http::geturl $api_url -timeout 5000} tok]} { return "" }
        if {[::http::status $tok] eq "ok" && [::http::ncode $tok] == 200} {
            set short [string trim [::http::data $tok]]
            ::http::cleanup $tok
            return $short
        }
        ::http::cleanup $tok
        return ""
    }

    # --------------------------------------------------------------------------
    # DATE FORMATTER HELPER
    # --------------------------------------------------------------------------
    proc format_pubdate {raw_date} {
        if {[catch {clock scan $raw_date} epoch]} { return "" }
        return [clock format $epoch -format "%d-%m-%Y %I %p"]
    }

    # --------------------------------------------------------------------------
    # CORE PARSER
    # --------------------------------------------------------------------------
    proc fetch_news {gl hl} {
        variable max_items
        set url "https://news.google.com/rss?hl=${hl}-${gl}&gl=${gl}&ceid=${gl}:${hl}"
        
        set tok [::http::geturl $url -timeout 10000]
        if {[::http::status $tok] ne "ok"} {
            ::http::cleanup $tok
            return [list [list "Error: Unable to connect to Google News server." "" ""]]
        }
        
        set data [::http::data $tok]
        ::http::cleanup $tok

        set headlines [list]
        set count 0
        set startIdx 0

        while {[set itemStart [string first "<item>" $data $startIdx]] != -1 && $count < $max_items} {
            set itemEnd [string first "</item>" $data $itemStart]
            if {$itemEnd == -1} break
            
            set itemData [string range $data $itemStart $itemEnd]
            set title ""
            set link ""
            set date_str ""
            
            if {[regexp {<title>(.*?)</title>} $itemData -> raw_title]} {
                regsub -all {<!\[CDATA\[} $raw_title "" raw_title
                regsub -all {\]\]>} $raw_title "" raw_title
                set title [string map {&quot; "\"" &amp; "&" &lt; "<" &gt; ">" &#39; "'"} $raw_title]
                set title [string trim $title]
            }
            
            regexp {<link>(.*?)</link>} $itemData -> link
            regexp {<pubDate>(.*?)</pubDate>} $itemData -> raw_date
            
            if {$title ne ""} {
                set short_link ""
                if {$link ne ""} { set short_link [shorten_url $link] }
                set clean_date [format_pubdate $raw_date]
                
                lappend headlines [list $title $short_link $clean_date]
                incr count
            }
            set startIdx $itemEnd
        }
        return $headlines
    }

    # --------------------------------------------------------------------------
    # PUBLIC COMMAND ACCESSIBILITY
    # --------------------------------------------------------------------------
    proc pub_news {nick uhost hand chan arg} {
        set gl [string toupper [string trim [lindex [split $arg] 0]]]
        if {$gl eq ""} {
            putquick "NOTICE $nick :Usage: !news <2-letter country code> (e.g. !news US, !news GB)"
            return
        }

        putquick "PRIVMSG $chan :Checking latest Google News lines for \002$gl\002..."
        set hl [string tolower $gl]
        if {$gl eq "US" || $gl eq "GB" || $gl eq "CA" || $gl eq "AU"} { set hl "en" }

        set results [fetch_news $gl $hl]
        if {[llength $results] == 0} {
            putquick "PRIVMSG $chan :No recent headlines found for region: $gl"
            return
        }

        foreach item $results {
            set title [lindex $item 0]
            set url   [lindex $item 1]
            set time  [lindex $item 2]
            
            set link_str ""
            if {$url ne ""} { set link_str " ($url)" }
            set date_str ""
            if {$time ne ""} { set date_str ", Last updated $time" }
            
            putquick "PRIVMSG $chan :[subst {\00304-\00302}] $title\00314$link_str\003$date_str"
            after 500
        }
    }

    # --------------------------------------------------------------------------
    # AUTOMATED CUSTOMIZABLE TIMER LOOP
    # --------------------------------------------------------------------------
    proc auto_news_loop {} {
        variable channel
        variable default_gl
        variable default_hl
        variable auto_timer

        # Safety fallback: force interval to minimum of 1 minute to avoid lockups
        if {![string is integer -strict $auto_timer] || $auto_timer < 1} {
            set auto_timer 60
        }

        # Logic checking if bot is actually in the target channel
        if {[validchan $channel] && [onchan $::botnick $channel]} {
            set results [fetch_news $default_gl $default_hl]
            if {[llength $results] > 0} {
                # FIX: Changed [string uppercase ...] to [string toupper ...]
                putquick "PRIVMSG $channel :\002\[Google News Update - [string toupper $default_gl]\]\002 Top Stories:"
                foreach item $results {
                    set title [lindex $item 0]
                    set url   [lindex $item 1]
                    set time  [lindex $item 2]
                    
                    set link_str ""
                    if {$url ne ""} { set link_str " ($url)" }
                    set date_str ""
                    if {$time ne ""} { set date_str ", Last updated $time" }
                    
                    putquick "PRIVMSG $channel :[subst {\00304•\003}] $title\00314$link_str\003$date_str"
                    after 500
                }
            }
        }

        # Reschedule the next run based on the configuration variable (in seconds)
        set delay_seconds [expr {$auto_timer * 60}]
        utimer $delay_seconds [namespace current]::auto_news_loop
    }
}

putlog "Loaded Egg News RSS Engine with an adjustable $::GoogleNews::auto_timer-minute loop."
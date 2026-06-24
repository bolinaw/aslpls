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
# EggFML.tcl - FuckMyLife Automated Channel Streamer           
# Author: asl_pls                                  
#
##############################################################

package require http
package require tls

namespace eval ::fml {
    # ------------------ CONFIGURATION ------------------
    # Space-separated list of channels where the script should post
    variable channels { "#aslpls" }
    
    # Public command to trigger a story manually (set to "" to disable)
    variable pub_trigger "!fml"
    
    # Frequency to automate posts (in minutes)
    variable timer_mins "60"
    
    # Prefix for bot messages in the channel
    variable text_prefix "\00304\[F*ckMyLife\]\003"
    
    # RSS Feed URL
    variable url "https://www.fmylife.com/rss"
    # ---------------------------------------------------

    # Register the HTTPS socket protocol
    ::http::register https 443 [list ::tls::socket -autoservername 1]

    # Initialize Public Bind
    if {$pub_trigger ne ""} {
        bind pub - $pub_trigger [namespace current]::pub_fetch
    }

    # Main fetching and parsing procedure
    proc fetch_story {} {
        variable url
        
        set headers [list "User-Agent" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Eggdrop/1.9"]
        
        if {[catch {
            set token [::http::geturl $url -headers $headers -timeout 10000]
        } error]} {
            putlog "FML Error: Failed to open connection: $error"
            return ""
        }

        if {[::http::status $token] ne "ok"} {
            putlog "FML Error: HTTP request status: [::http::status $token]"
            ::http::cleanup $token
            return ""
        }

        set data [::http::data $token]
        ::http::cleanup $token

        set descriptions {}
        set items [regexp -all -inline {<item>.*?</item>} $data]
        
        foreach item $items {
            if {[regexp {<description>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</description>} $item -> desc]} {
                set cleaned [clean_text $desc]
                if {$cleaned ne ""} {
                    lappend descriptions $cleaned
                }
            }
        }

        if {[llength $descriptions] == 0} {
            return ""
        }

        return [lindex $descriptions [expr {int(rand() * [llength $descriptions])}]]
    }

    # Decodes basic HTML entities
    proc clean_text {text} {
        regsub -all -nocase {<br\s*/?>.*$} $text "" text
        regsub -all -nocase {<[^>]*>} $text "" text
        
        set map {
            "&quot;" "\""
            "&amp;"  "&"
            "&lt;"   "<"
            "&gt;"   ">"
            "&#039;" "'"
            "&apos;" "'"
            "&#39;"  "'"
            "&nbsp;" " "
        }
        return [string trim [string map $map $text]]
    }

    # Automated timer loop handler
    proc timer_loop {} {
        variable channels
        variable text_prefix
        variable timer_mins
        
        # Kill any accidentally orphaned loops to prevent duplicate timing chains
        foreach t [utimers] {
            if {[lindex $t 1] eq "[namespace current]::timer_loop"} {
                killutimer [lindex $t 2]
            }
        }

        # Fetch and broadcast
        set story [fetch_story]
        if {$story ne ""} {
            foreach chan $channels {
                if {[validchan $chan]} {
                    putquick "PRIVMSG $chan :$text_prefix $story"
                }
            }
        }

        # Reschedule next run based on user setting (converted from minutes to seconds)
        set delay_seconds [expr {$timer_mins * 60}]
        utimer $delay_seconds [namespace current]::timer_loop
    }

    # Manual !fml on-demand command handler
    proc pub_fetch {nick uhost hand chan arg} {
        variable text_prefix
        
        set story [fetch_story]
        if {$story ne ""} {
            putquick "PRIVMSG $chan :$text_prefix $story"
        } else {
            putquick "NOTICE $nick :Could not fetch an FML story right now. Please try again later."
        }
    }

    # Start the initial loop on script load (staggered by 10 seconds to let bot fully connect)
    utimer 10 [namespace current]::timer_loop

    putlog "Loaded EggFML.tcl - Automating posts every $timer_mins minutes."
}
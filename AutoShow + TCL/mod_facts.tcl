############# Random FunFacts ##################
# A simple script to post random funfacts in   #
# multiple channels.                           #
#                                              #
# The bot randomly fetches funfacts from       #
# http://www.randomfunfacts.com/ and posts it  #
# to the allocated channels every x minutes.   #
#                                              #
# Installation:                                #
# pop the script in your script folder and add #
# source scripts/fact.tcl to your eggdrop conf #
# file rehash / restart the bot.               #
########## Update as of June 2026 ##############
# Added and modified in the script that allow  #
# to show in multiple channels.                #
################################################

package require http

################################################
#                Configuration                 #
#                                              #
#  Allocate your channels here (space separated) #
################################################

set channels "#aslpls #uae #bingo #buangons"

#################################################
# Random facts timer. change it according to    #
# your needs.                                   #
#################################################

set time 5

#################################################
# Please dont touch anything below unless you   #
# know what you are doing.                      #
#################################################

if {[string compare [string index $time 0] "!"] == 0} { 
    set timer [string range $time 1 end] 
} { 
    set timer [expr {$time * 60}] 
} 

if {[lsearch -glob [utimers] "* fact *"] == -1} { 
    utimer $timer fact 
}

proc fact {} { 
    # FIX: Added 'channels' to the global declaration list
    global channels time timer 
    set url "http://www.randomfunfacts.com/"
    
    # Fetch the page safely
    if {[catch {set token [http::geturl $url -timeout 5000]} error]} {
        putlog "FunFacts Error: $error"
        if {[lsearch -glob [utimers] "* fact *"] == -1} { utimer $timer fact }
        return
    }
    
    set page [http::data $token]
    http::cleanup $token

    if {[regexp {<i>(.*?)<\/i>} $page a fact_text]} {
        # Loop through each channel in the global list
        foreach chan $channels { 
            if {[validchan $chan]} {
                putserv "PRIVMSG $chan :$fact_text" 
            }
        } 
    }
    
    if {[lsearch -glob [utimers] "* fact *"] == -1} { 
        utimer $timer fact 
    } 
}

putlog "funfact.tcl 1.2 (Multi-Channel Random Fun Facts Fixed) Loaded."

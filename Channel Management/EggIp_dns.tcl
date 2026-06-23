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
# 	EggIp_dns.tcl                                                         	
# 	An upgraded Eggdrop script for IP, DNS, and Reverse DNS lookups.           		
# 	Includes built-in flood protection and localized time/maps.               		
#                                                                             		
# 	Commands:                                                                   	
#   	!ip <IP Address>                                                          	
#   	!dns <Domain> [Record Type]                                               	
#   	!rdns <IP Address>                                                        	
#																					
############################################################################################

package require http
package require tls

# Register HTTPS support
::http::register https 443 [list ::tls::socket]

# Configuration
set ipdns(flood_seconds) 5  ;# Minimum seconds a user must wait between requests
set ipdns(ignore_ops) 1     ;# Set to 1 to allow Channel Ops to bypass flood control

# Global array to track user cooldowns
variable ipdns_cooldown

# Bindings
bind pub - !ip pub_iplookup
bind pub - !dns pub_dnslookup
bind pub - !rdns pub_rdnslookup

# Helper: Flood Protection Check
proc is_flooding {nick chan} {
    global ipdns ipdns_cooldown
    
    # If bypass is enabled and user is an op, allow it
    if {$ipdns(ignore_ops) && [isop $nick $chan]} { return 0 }
    
    set now [clock seconds]
    if {[info exists ipdns_cooldown($nick)]} {
        set elapsed [expr {$now - $ipdns_cooldown($nick)}]
        if {$elapsed < $ipdns(flood_seconds)} {
            set wait [expr {$ipdns(flood_seconds) - $elapsed}]
            putquick "NOTICE $nick :Please wait $wait more second(s) before using lookup commands again."
            return 1
        }
    }
    set ipdns_cooldown($nick) $now
    return 0
}

proc pub_iplookup {nick uhost hand chan text} {
    if {[is_flooding $nick $chan]} { return }
    
    set ip [string trim [lindex [split $text] 0]]
    if {$ip == ""} {
        putquick "PRIVMSG $chan :Usage: !ip <IP address>"
        return
    }
    
    set url "http://ip-api.com/json/$ip"
    
    if {[catch {
        set token [::http::geturl $url -timeout 5000]
        set data [::http::data $token]
        ::http::cleanup $token
        
        if {[regexp {"status":"success"} $data]} {
            set country "Unknown"; set city "Unknown"; set isp "Unknown"; set as "Unknown"
            set tz "UTC"; set lat ""; set lon ""
            
            regexp {"country":"([^"]+)"} $data -> country
            regexp {"city":"([^"]+)"} $data -> city
            regexp {"isp":"([^"]+)"} $data -> isp
            regexp {"as":"([^"]+)"} $data -> as
            regexp {"timezone":"([^"]+)"} $data -> tz
            regexp {"lat":(-?\d+\.?\d*)} $data -> lat
            regexp {"lon":(-?\d+\.?\d*)} $data -> lon
            
            # Calculate local time of the IP target if timezone is available
            set local_time "Unknown"
            if {[catch {set local_time [clock format [clock seconds] -format "%I:%M %p (%Z)" -timezone :$tz]} err]} {
                set local_time "Unknown"
            }
            
            set map_url "https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=12/$lat/$lon"
            
            putquick "PRIVMSG $chan :\[IP Lookup\] $ip \x02->\x02 City: $city, Country: $country | Time: $local_time | ISP: $isp ($as)"
            putquick "PRIVMSG $chan :\[Map\] $map_url"
        } else {
            putquick "PRIVMSG $chan :\[IP Lookup\] Failed to resolve or invalid IP address."
        }
    } error]} {
        putquick "PRIVMSG $chan :\[IP Lookup\] API Error: $error"
    }
}

proc pub_dnslookup {nick uhost hand chan text} {
    if {[is_flooding $nick $chan]} { return }
    
    set args [split [string trim $text]]
    set domain [lindex $args 0]
    set type [string toupper [lindex $args 1]]
    
    if {$domain == ""} {
        putquick "PRIVMSG $chan :Usage: !dns <domain> \[type, e.g., A, MX, TXT\]"
        return
    }
    if {$type == ""} { set type "A" }
    
    set url "https://dns.google/resolve?name=$domain&type=$type"
    
    if {[catch {
        set token [::http::geturl $url -timeout 5000]
        set data [::http::data $token]
        ::http::cleanup $token
        
        if {[regexp {"Answer":\s*\[(.*?)\]} $data -> answer_block]} {
            set records {}
            set matches [regexp -all -inline {"data":"([^"]+)"} $answer_block]
            
            foreach {dummy val} $matches {
                set val [string map {\\"" ""} $val]
                lappend records $val
            }
            
            if {[llength $records] > 0} {
                putquick "PRIVMSG $chan :\[DNS Lookup\] $domain ($type) \x02->\x02 [join $records {, }]"
            } else {
                putquick "PRIVMSG $chan :\[DNS Lookup\] No records found for $domain ($type)."
            }
        } else {
            putquick "PRIVMSG $chan :\[DNS Lookup\] No answer returned."
        }
    } error]} {
        putquick "PRIVMSG $chan :\[DNS Lookup\] API Error: $error"
    }
}

proc pub_rdnslookup {nick uhost hand chan text} {
    if {[is_flooding $nick $chan]} { return }
    
    set ip [string trim [lindex [split $text] 0]]
    if {$ip == ""} {
        putquick "PRIVMSG $chan :Usage: !rdns <IP address>"
        return
    }
    
    # Simple check to construct reverse lookup syntax for IPv4
    if {[regexp {^(\d+)\.(\d+)\.(\d+)\.(\d+)$} $ip -> o1 o2 o3 o4]} {
        set lookup_target "$o4.$o3.$o2.$o1.in-addr.arpa"
    } else {
        putquick "PRIVMSG $chan :\[Reverse DNS\] Please provide a valid IPv4 address."
        return
    }
    
    set url "https://dns.google/resolve?name=$lookup_target&type=PTR"
    
    if {[catch {
        set token [::http::geturl $url -timeout 5000]
        set data [::http::data $token]
        ::http::cleanup $token
        
        if {[regexp {"Answer":\s*\[(.*?)\]} $data -> answer_block]} {
            if {[regexp {"data":"([^"]+)"} $answer_block -> hostname]} {
                # Clean up trailing dot often returned in DNS PTR data
                set hostname [string trimright $hostname "."]
                putquick "PRIVMSG $chan :\[Reverse DNS\] $ip \x02->\x02 $hostname"
            } else {
                putquick "PRIVMSG $chan :\[Reverse DNS\] Could not extract hostname for $ip."
            }
        } else {
            putquick "PRIVMSG $chan :\[Reverse DNS\] No PTR record found for $ip."
        }
    } error]} {
        putquick "PRIVMSG $chan :\[Reverse DNS\] API Error: $error"
    }
}

putlog "Loaded EggIp_dns.tcl Enhanced IP, DNS & RDNS script with Flood Control."

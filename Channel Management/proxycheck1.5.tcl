##############################################################
#	_______ ______________ ________ ______ ________
#	___    |__  ___/___  / ___  __ \___  / __  ___/
#	__  /| |_____ \ __  /  __  /_/ /__  /  _____ \ 
#	_  ___ |____/ / _  /____  ____/ _  /_______/ / 
#	/_/  |_|/____/  /_____//_/      /_____//____/  
#		  asl_pls / irc.underx.org	
#							
##############################################################
#
# 	Proxycheck.io IP & Nick Checker for Eggdrop
#
# 	Version: 1.5
#
# 	Commands: 
#   	!checkip <IP>
#   	!checknick <Nickname>
#
#############################################################

namespace eval ::ProxyCheck {
    # --- CONFIGURATION ---
    variable apiKey "YOUR-API-KEY-HERE" #Proxycheck.io
    variable cmdToken "!"
    variable userLevel "-" ;# Access level required (e.g., '-' for all, 'm' for masters)

    # --- BINDINGS ---
    bind pub $userLevel "${cmdToken}checkip" [namespace current]::pub_checkip
    bind pub $userLevel "${cmdToken}checknick" [namespace current]::pub_checknick

    # --- PACKAGES ---
    package require http
    package require json

    # Command: !checknick <nickname>
    proc pub_checknick {nick uhost hand chan text} {
        set targetNick [string trim [lindex [split $text] 0]]

        if {$targetNick eq ""} {
            putquick "PRIVMSG $chan :Usage: ${::ProxyCheck::cmdToken}checknick <Nickname>"
            return 0
        }

        # Check if the bot can see the user in the channel
        if {![onchan $targetNick $chan]} {
            putquick "PRIVMSG $chan :I don't see '$targetNick' in $chan."
            return 0
        }

        # Get the user's host (ident@host.domain)
        set targetHost [getchanhost $targetNick $chan]
        if {$targetHost eq ""} {
            putquick "PRIVMSG $chan :Could not retrieve hostname for $targetNick."
            return 0
        }

        # Strip the ident part to get just the hostname/IP
        set hostname [lindex [split $targetHost "@"] 1]

        # Regular expression to match IPv4 or IPv6 format directly
        set ipv4_regex {^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$}
        set ipv6_regex {^([0-9a-fA-F]{1,4}:){1,7}[0-9a-fA-F]{1,4}$|^\s*((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(25[0-5]|2[0-4]\d|[01]?\d\d?)|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(25[0-5]|2[0-4]\d|[01]?\d\d?)|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(25[0-5]|2[0-4]\d|[01]?\d\d?))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(25[0-5]|2[0-4]\d|[01]?\d\d?))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(25[0-5]|2[0-4]\d|[01]?\d\d?))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(25[0-5]|2[0-4]\d|[01]?\d\d?))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(25[0-5]|2[0-4]\d|[01]?\d\d?))|:)))(%.+)?\s*$}

        if {[regexp $ipv4_regex $hostname] || [regexp $ipv6_regex $hostname]} {
            # It's already a raw IP (v4 or v6), skip DNS entirely
            putquick "PRIVMSG $chan :Checking IP ($hostname) for $targetNick..."
            fetch_proxy_data $hostname $chan
        } else {
            # It's a text hostname, proceed to resolve it safely
            putquick "PRIVMSG $chan :Resolving host for $targetNick..."
            dnslookup $hostname [namespace current]::dns_callback $chan $targetNick
        }
        return 1
    }

    # Callback function after DNS resolution completes
    proc dns_callback {ip hostname status chan targetNick} {
        if {!$status} {
            putquick "PRIVMSG $chan :Failed to resolve IP for $targetNick ($hostname)."
            return 0
        }
        
        putquick "PRIVMSG $chan :Checking IP ($ip) for $targetNick..."
        fetch_proxy_data $ip $chan
    }

    # Command: !checkip <IP>
    proc pub_checkip {nick uhost hand chan text} {
        set ip [string trim [lindex [split $text] 0]]

        if {$ip eq ""} {
            putquick "PRIVMSG $chan :Usage: ${::ProxyCheck::cmdToken}checkip <IP Address>"
            return 0
        }

        fetch_proxy_data $ip $chan
        return 1
    }

    # Core logic: Interacts with the API and prints results
    proc fetch_proxy_data {ip chan} {
        variable apiKey
        set url "http://proxycheck.io/v2/$ip?key=$apiKey&vpn=1&asn=1"

        if {[catch {set token [::http::geturl $url -timeout 5000]} err]} {
            putquick "PRIVMSG $chan :Error contacting Proxycheck.io: $err"
            return 0
        }

        if {[::http::status $token] ne "ok"} {
            putquick "PRIVMSG $chan :API request failed or timed out."
            ::http::cleanup $token
            return 0
        }

        set data [::http::data $token]
        ::http::cleanup $token

        if {[catch {set parsed [::json::json2dict $data]} err]} {
            putquick "PRIVMSG $chan :Error parsing API response."
            return 0
        }

        set status [dict get $parsed status]
        if {$status ne "ok"} {
            set message [expr {[dict exists $parsed message] ? [dict get $parsed message] : "Unknown API Error"}]
            putquick "PRIVMSG $chan :Proxycheck.io Error: $message"
            return 0
        }

        if {[dict exists $parsed $ip]} {
            set ipData [dict get $parsed $ip]
            
            set isProxy [expr {[dict exists $ipData proxy] ? [dict get $ipData proxy] : "no"}]
            set type [expr {[dict exists $ipData type] ? [dict get $ipData type] : "N/A"}]
            set country [expr {[dict exists $ipData country] ? [dict get $ipData country] : "Unknown"}]
            set provider [expr {[dict exists $ipData provider] ? [dict get $ipData provider] : "Unknown"}]

            # Formatting IRC colors
            set color_bold "\002"
            set color_red "\00304"
            set color_green "\00303"
            set color_reset "\003"

            if {$isProxy eq "yes"} {
                set statusStr "${color_red}RISKY (Proxy/VPN detected)${color_reset}"
            } else {
                set statusStr "${color_green}CLEAN (Residential/Normal)${color_reset}"
            }

            putquick "PRIVMSG $chan :${color_bold}\[IP Check\]${color_reset} $ip -> Status: $statusStr | Type: ${color_bold}$type${color_reset} | Provider: $provider | Country: $country"
        } else {
            putquick "PRIVMSG $chan :No data returned for IP: $ip"
        }
    }

    putlog "Loaded: Proxycheck.io IP & Nick Checker Script v1.5"
}

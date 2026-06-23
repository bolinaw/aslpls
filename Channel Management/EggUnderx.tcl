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
# EggUnderx.tcl by asl_pls @ irc.underx.org #aslpls                              
# An Eggdrop script for UnderX Service Management & Authentication.           
#
############################################################################################
#                                                                             
#  How to use it in your channels:                                            
#  The script automatically detects the channel you are typing in so you      
#    don't have to keep writing #channel. Make sure your Eggdrop is logged    
#    in as a master or manager in X for the specific channel to perform these  
#    commands.                                                                
#                                                                             
#  To add a user:                 .xadd TargetUser 100                        
#  To remove a user:              .xdel TargetUser                            
#  To change access level:        .xlevel TargetUser 150                        
#  To change automode to OP:      .xmode TargetUser op                        
#  To change automode to VOICE:   .xmode TargetUser voice                        
#  To turn off automode:          .xmode TargetUser none                        
#                                                                                
#############################################################################################

# --- Configuration ---
namespace eval ::UnderX {
    # Your X service username and password
    variable x_user "username"
    variable x_pass "password"

    # The flag required to use the channel management commands in IRC
    # 'n' means only Eggdrop owners can use them. Change to 'o' for any op.
    variable cmd_flag "n"

    # Command prefix (e.g., .xadd, .xdel)
    variable cmd_prefix "."
}

# --- Initialization & Authentication Bindings ---
bind evnt - init-server ::UnderX::on_connect

proc ::UnderX::on_connect {type} {
    variable x_user
    variable x_pass
    # Delay slightly to allow the server connection to stabilize
    utimer 3 [list ::UnderX::do_login $x_user $x_pass]
}

proc ::UnderX::do_login {user pass} {
    if {$user eq "YourXUsername"} {
        putlog "\[UnderX\] WARNING: Please configure your X username and password in the script!"
        return
    }
    putlog "\[UnderX\] Authenticating with X@channels.underx.org..."
    putserv "PRIVMSG X@channels.underx.org :login $user $pass"
    
    # Request hidden host (+x mode)
    utimer 2 [list putserv "MODE $::botnick +x"]
}

# --- Public Command Bindings ---
bind pub $::UnderX::cmd_flag "${::UnderX::cmd_prefix}xadd"     ::UnderX::pub_xadd
bind pub $::UnderX::cmd_flag "${::UnderX::cmd_prefix}xdel"     ::UnderX::pub_xdel
bind pub $::UnderX::cmd_flag "${::UnderX::cmd_prefix}xlevel"   ::UnderX::pub_xlevel
bind pub $::UnderX::cmd_flag "${::UnderX::cmd_prefix}xmode"     ::UnderX::pub_xmode

# --- Command Implementations ---

# Syntax: .xadd <username> <access_level>
proc ::UnderX::pub_xadd {nick uhost hand chan arg} {
    set target_user [lindex [split $arg] 0]
    set access_level [lindex [split $arg] 1]

    if {$target_user eq "" || $access_level eq ""} {
        putquick "NOTICE $nick :Syntax: ${::UnderX::cmd_prefix}xadd <username> <access_level>"
        return
    }

    putlog "\[UnderX\] $nick requested adduser for $target_user level $access_level on $chan"
    putserv "PRIVMSG X@channels.underx.org :adduser $chan $target_user $access_level"
    putquick "NOTICE $nick :Sent adduser request to X for $target_user ($access_level) on $chan."
}

# Syntax: .xdel <username>
proc ::UnderX::pub_xdel {nick uhost hand chan arg} {
    set target_user [lindex [split $arg] 0]

    if {$target_user eq ""} {
        putquick "NOTICE $nick :Syntax: ${::UnderX::cmd_prefix}xdel <username>"
        return
    }

    putlog "\[UnderX\] $nick requested remuser for $target_user on $chan"
    putserv "PRIVMSG X@channels.underx.org :remuser $chan $target_user"
    putquick "NOTICE $nick :Sent remuser request to X for $target_user on $chan."
}

# Syntax: .xlevel <username> <new_access_level>
proc ::UnderX::pub_xlevel {nick uhost hand chan arg} {
    set target_user [lindex [split $arg] 0]
    set access_level [lindex [split $arg] 1]

    if {$target_user eq "" || $access_level eq ""} {
        putquick "NOTICE $nick :Syntax: ${::UnderX::cmd_prefix}xlevel <username> <new_access_level>"
        return
    }

    putlog "\[UnderX\] $nick requested modinfo access change for $target_user to $access_level on $chan"
    putserv "PRIVMSG X@channels.underx.org :modinfo $chan access $target_user $access_level"
    putquick "NOTICE $nick :Sent modinfo level update to X for $target_user on $chan."
}

# Syntax: .xmode <username> <op|voice|none>
proc ::UnderX::pub_xmode {nick uhost hand chan arg} {
    set target_user [lindex [split $arg] 0]
    set mode_type [string tolower [lindex [split $arg] 1]]

    if {$target_user eq "" || ($mode_type ne "op" && $mode_type ne "voice" && $mode_type ne "none")} {
        putquick "NOTICE $nick :Syntax: ${::UnderX::cmd_prefix}xmode <username> <op|voice|none>"
        return
    }

    # Map the user input to the exact X automode syntax strings
    switch -- $mode_type {
        "op"    { set x_arg "op on" }
        "voice" { set x_arg "voice on" }
        "none"  { set x_arg "none" }
    }

    putlog "\[UnderX\] $nick requested automode change for $target_user to $mode_type on $chan"
    putserv "PRIVMSG X@channels.underx.org :modinfo $chan automode $target_user $x_arg"
    putquick "NOTICE $nick :Sent automode update ($mode_type) to X for $target_user on $chan."
}

putlog "Successfully loaded EggUnderx.tcl with UnderX by asl_pls @ irc.underx.org #aslpls"

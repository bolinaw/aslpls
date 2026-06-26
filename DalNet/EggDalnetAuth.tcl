#################################################################
#	_______ ______________ ________ ______ ________
#	___    |__  ___/___  / ___  __ \___  / __  ___/
#	__  /| |_____ \ __  /  __  /_/ /__  /  _____ \ 
#	_  ___ |____/ / _  /____  ____/ _  /_______/ / 
#	/_/  |_|/____/  /_____//_/      /_____//____/  
#		  asl_pls / irc.underx.org	
#							
#################################################################
# DALnet Auto-Identify Script for Eggdrop                       #
# Hooks into connection success to securely message NickServ    #
#################################################################

namespace eval ::DalnetAuth {
    # -----------------------------------------------------------
    # CONFIGURATION
    # -----------------------------------------------------------
    variable nick "username"
    variable pass "password"
    
    # Set this to 1 if you want the bot to attempt to GHOST its 
    # nick if someone else (or a stuck connection) is using it.
    variable use_ghost 1

    # -----------------------------------------------------------
    # BINDINGS & CORE LOGIC
    # -----------------------------------------------------------
    bind raw - 376 [namespace current]::on_connect
    bind raw - 422 [namespace current]::on_connect
    # FIXED: Changed 'notice' to 'notc'
    bind notc - * [namespace current]::on_notice

    proc on_connect {from keyword args} {
        variable nick
        variable pass
        variable use_ghost

        # FIXED: Removed 'string columns' which is invalid Tcl and replaced with a valid length check
        if {[info exists ::network] && [string length $::network] && [string tolower $::network] ne "dalnet"} {
            # Optional: Remove or comment out if your eggdrop doesn't set $network natively
        }

        putlog "\[DALnet-Auth\] Connected. Verifying nickname status..."

        # Check if the bot currently has its primary nick
        if {[string tolower $::botnick] ne [string tolower $nick]} {
            if {$use_ghost} {
                putlog "\[DALnet-Auth\] Primary nick '$nick' is in use. Issuing GHOST command."
                putserv "PRIVMSG NickServ :GHOST $nick $pass"
            }
        } else {
            putlog "\[DALnet-Auth\] Identifying to NickServ..."
            putserv "PRIVMSG NickServ :IDENTIFY $pass"
        }
        return 0
    }

    proc on_notice {from keyword text} {
        variable nick
        variable pass

        # Target notice tracking from NickServ
        if {[string tolower $from] eq "nickserv!service@dal.net" || [string tolower $from] eq "nickserv"} {
            
            # NickServ successfully ghosted the old connection
            if {[string match -nocase "*has been ghosted*" $text] || [string match -nocase "*has been disconnected*" $text]} {
                putlog "\[DALnet-Auth\] Ghost successful. Reclaiming nickname '$nick'..."
                putserv "NICK $nick"
            }
            
            # Once the nick change succeeds, Eggdrop natively updates $::botnick.
            # We catch the successful identification acknowledgment just for logs.
            if {[string match -nocase "*Password accepted*" $text] || [string match -nocase "*now identified*" $text]} {
                putlog "\[DALnet-Auth\] Successfully identified with NickServ."
            }
        }
        return 0
    }

    # Re-auth trigger if the bot manually reclaims its nick later
    bind nick - * [namespace current]::on_nickchange
    proc on_nickchange {from key newnick} {
        variable nick
        variable pass
        if {[string tolower $newnick] eq [string tolower $nick]} {
            putlog "\[DALnet-Auth\] Nick reclaimed via partyline/split. Re-identifying..."
            putserv "PRIVMSG NickServ :IDENTIFY $pass"
        }
    }
}

putlog "Loaded EggDalnetAuth.tcl DALnet Auto-Identify Script successfully."

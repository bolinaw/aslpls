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
# EggJoinPart.tcl by asl_pls
# Permanent !join and !part commands for Bot Owners
#
########################################################################################### 

# Bind the public commands
# "n" means only users with the GLOBAL OWNER flag can use these.
bind pub n !join pub_join_chan
bind pub n !part pub_part_chan

proc pub_join_chan {nick uhost hand chan arg} {
    # Extract the target channel from the arguments
    set target [lindex [split $arg] 0]
    
    if {$target eq ""} {
        putquick "PRIVMSG $chan :Usage: !join <#channel>"
        return 0
    }
    
    # Check if the channel name starts with a valid prefix (usually #)
    if {![string match "#*" $target]} {
        putquick "PRIVMSG $chan :Error: Channel names must start with #."
        return 0
    }
    
    # Check if the bot is already in or managing that channel
    if {[validchan $target]} {
        putquick "PRIVMSG $chan :I am already managing or sitting in $target."
        return 0
    }
    
    # Add the channel permanently to the bot's dynamic channel list
    channel add $target
    
    putquick "PRIVMSG $chan :Successfully joined and saved $target permanently."
    return 1
}

proc pub_part_chan {nick uhost hand chan arg} {
    # Extract the target channel, default to current channel if blank
    set target [lindex [split $arg] 0]
    
    if {$target eq ""} {
        set target $chan
    }
    
    # Check if the bot even knows about the channel
    if {![validchan $target]} {
        putquick "PRIVMSG $chan :I am not currently managing $target."
        return 0
    }
    
    # Remove the channel permanently from the bot's dynamic channel list
    channel remove $target
    
    # If parting a different channel than the one the command was typed in, 
    # let the owner know it worked.
    if {$target ne $chan} {
        putquick "PRIVMSG $chan :Successfully left and removed $target permanently."
    }
    
    return 1
}

putlog "Loaded: EggJoinPart.tcl by asl_pls (Permanent !join/!part)"

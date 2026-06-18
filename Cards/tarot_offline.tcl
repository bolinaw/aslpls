#####################################################################################
#                      ____  ____  _     ____  _     ____ 	                        #
#                     /  _ \/ ___\/ \   /  __\/ \   / ___\	                        #
#                     | / \||    \| |   |  \/|| |   |    \	                        #
#                     | |-||\___ || |_/\|  __/| |_/\\___ |	                        #
#                     \_/ \|\____/\____/\_/   \____/\____/	                        #
#                       asl_pls / irc.underx.org #aslpls    	                    #
#####################################################################################
#                                                                                   #
# Eggdrop IRC Tarot Card Reading Script                                             #
# tarot.tcl by asl_pls @ irc.underx.org #aslpls                                     #
#                                                                                   #          
# Commands: !tarot [nick]                                                           # 
#                                                                                   # 
#####################################################################################

namespace eval ::Tarot {
    # --- Configuration ---
    variable cmdChar "!"
    variable cooldown 10 ;# Cooldown in seconds per user to prevent spam

    # --- Global Tracking ---
    variable lastUse
    if {![info exists lastUse]} { array set lastUse {} }

    # --- The Major Arcana Deck ---
    # Format: { "Card Name" "Upright Meaning" "Reversed Meaning" }
    variable deck {
        {"The Fool" "New beginnings, optimism, trust in life." "Recklessness, risk-taking, holding back."}
        {"The Magician" "Action, power, manifestation, resourcefulness." "Illusion, out-of-touch, wasted talent."}
        {"The High Priestess" "Intuition, sacred knowledge, divine feminine." "Secret agendas, ignoring your gut, surface-level focus."}
        {"The Empress" "Abundance, creativity, nature, nurturing." "Dependence, creative block, smothering."}
        {"The Emperor" "Authority, structure, solid foundation, protection." "Tyranny, rigidity, coldness, lack of discipline."}
        {"The Hierophant" "Tradition, spiritual wisdom, institutions, conformity." "Rebellion, subversion, new approaches."}
        {"The Lovers" "Harmony, relationships, choices, alignment of values." "Disharmony, misalignment, bad choices."}
        {"The Chariot" "Direction, control, willpower, victory." "Lack of control, directionless, aggression."}
        {"Strength" "Courage, inner strength, compassion, patience." "Self-doubt, weakness, raw emotion."}
        {"The Hermit" "Soul-searching, introspection, inner guidance." "Isolation, loneliness, withdrawal."}
        {"Wheel of Fortune" "Good luck, karma, destiny, turning point." "Bad luck, resisting change, breaking cycles."}
        {"Justice" "Fairness, truth, law, cause and effect." "Dishonesty, unaccountability, unfairness."}
        {"The Hanged Man" "Pause, surrender, letting go, new perspectives." "Delay, resistance, stalling, stagnation."}
        {"Death" "Endings, change, transformation, transition." "Resistance to change, personal purgatory."}
        {"Temperance" "Balance, moderation, patience, purpose." "Imbalance, excess, self-healing needed."}
        {"The Devil" "Shadow self, attachment, addiction, materialism." "Releasing limiting beliefs, detachment, freedom."}
        {"The Tower" "Sudden change, upheaval, chaos, revelation." "Avoiding disaster, delaying the inevitable, fear of change."}
        {"The Star" "Hope, faith, purpose, renewal." "Lack of faith, despair, discouragement."}
        {"The Moon" "Illusion, fear, anxiety, subconscious." "Release of fear, repressed emotion, clearing confusion."}
        {"The Sun" "Positivity, fun, warmth, success, vitality." "Inner child, feeling down, overly optimistic."}
        {"Judgement" "Reflection, reckoning, awakening." "Self-doubt, inner critic, ignoring the call."}
        {"The World" "Completion, integration, accomplishment, travel." "Seeking closure, shortcuts, delays."}
    }

    # --- Bindings ---
    bind pub - "${cmdChar}tarot" [namespace current]::drawCard

    # --- Core Logic ---
    proc drawCard {nick uhost hand chan arg} {
        variable deck
        variable cooldown
        variable lastUse

        # Anti-spam check
        set now [clock seconds]
        if {[info exists lastUse($nick)] && [expr {$now - $lastUse($nick)}] < $cooldown} {
            set remaining [expr {$cooldown - ($now - $lastUse($nick))}]
            puthelp "NOTICE $nick :Please wait $remaining more seconds before drawing another card."
            return 0
        }
        set lastUse($nick) $now

        # Pick a random card from the deck
        set totalCards [llength $deck]
        set randomIndex [expr {int(rand() * $totalCards)}]
        set cardData [lindex $deck $randomIndex]

        set cardName [lindex $cardData 0]
        set uprightMeaning [lindex $cardData 1]
        set reversedMeaning [lindex $cardData 2]

        # Determine orientation: 0 = Upright, 1 = Reversed (50/50 chance)
        set isReversed [expr {rand() > 0.5}]

        # Determine target of the reading
        set target [string trim $arg]
        if {$target eq ""} {
            set target $nick
        }

        # Format and send output with safely escaped string markers
        if {$isReversed} {
            puthelp "PRIVMSG $chan :\00306\[Tarot\]\003 \002$target\002 draws: \00304$cardName (REVERSED)\003 -> \00310Meaning:\003 $reversedMeaning"
        } else {
            puthelp "PRIVMSG $chan :\00306\[Tarot\]\003 \002$target\002 draws: \00303$cardName (UPRIGHT)\003 -> \00310Meaning:\003 $uprightMeaning"
        }
        return 1
    }

    putlog "Loaded: Tarot.tcl | asl_pls irc.underx.org #aslpls Loaded!"
}
